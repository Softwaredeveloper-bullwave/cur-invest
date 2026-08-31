from __future__ import annotations

import logging
import random
from datetime import timedelta

from django.conf import settings
from django.db import DatabaseError, close_old_connections
from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from core.db_health import database_unavailable_response
from core.integrations.bank_service import BankValidationError, validate_account_number, validate_ifsc
from core.integrations.cashfree_service import CashfreeError, is_configured as cashfree_configured
from core.integrations.cashfree_bypass import verify_bank_with_bypass, verify_pan_with_bypass
from core.integrations.sms_service import (
    SMSError,
    check_otp_2factor,
    check_otp_twilio_verify,
    friendly_2factor_error,
    friendly_infobip_error,
    friendly_twilio_error,
    is_live_sms,
    resolve_sms_provider,
    send_2factor_autogen_otp,
    send_2factor_manual_otp,
    send_otp_sms,
    twilio_verify_delivery_blocked,
    twilio_message_ready,
    uses_2factor,
    uses_2factor_autogen,
    uses_2factor_live,
    uses_2factor_manual,
    uses_twilio_verify,
)
from kyc.service import get_or_create_profile

from kyc.rate_limit import RateLimitExceeded, check_rate_limit

from core.serializers import CamelCaseSerializer
from .email_otp_service import EmailOtpError, _EMAIL_REGEX, normalize_email, send_email_otp, verify_email_otp
from .avatar_storage import ensure_media_dirs, normalize_avatar_upload
from .web_email_auth import (
    apply_verified_email_to_user,
    find_returning_web_user,
    resolve_email_proof_token,
    send_web_email_otp,
    verify_web_email_otp,
)
from .google_auth import GoogleAuthError, authenticate_with_google
from kyc.service import user_dob_verified_from_kyc
from .models import BankAccount, EmailOTPVerification, KycDocument, OTPVerification, User
from .otp_utils import normalize_otp, normalize_phone
from .serializers import (
    BankAccountSerializer,
    CompleteProfileSerializer,
    KycDocumentSerializer,
    KycStatusSerializer,
    ProfileUpdateSerializer,
    UserSerializer,
)

logger = logging.getLogger('bullwave.accounts')

DEV_AUTH_PHONE = '9999999999'


def _database_unavailable_response():
    return database_unavailable_response()


def _issue_auth_tokens(user, request, *, created=False):
    refresh = RefreshToken.for_user(user)
    return Response(
        {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user, context={'request': request}).data,
            'isNewUser': created,
        }
    )


def _ensure_user_bootstrap(user, *, created=False):
    from finance.models import Wallet
    from engagement.models import Notification

    get_or_create_profile(user)
    Wallet.objects.get_or_create(user=user)
    if created:
        Notification.objects.create(
            user=user,
            title='Welcome to BullWave',
            message='Complete your KYC to start investing.',
            type='general',
        )


class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def _issue_local_otp(self, phone: str, *, session_id: str = '') -> str:
        otp = f'{random.randint(100000, 999999):06d}'
        expires_at = timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        OTPVerification.objects.filter(phone=phone, is_used=False).update(is_used=True)
        OTPVerification.objects.create(
            phone=phone,
            otp_code=otp,
            session_id=session_id or '',
            expires_at=expires_at,
        )
        return otp

    def _issue_2factor_session(self, phone: str, session_id: str) -> None:
        expires_at = timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        OTPVerification.objects.filter(phone=phone, is_used=False).update(is_used=True)
        OTPVerification.objects.create(
            phone=phone,
            otp_code='000000',
            session_id=session_id,
            expires_at=expires_at,
        )

    @staticmethod
    def _attach_session_to_latest_otp(phone: str, session_id: str) -> None:
        latest = (
            OTPVerification.objects.filter(phone=phone, is_used=False)
            .order_by('-created_at')
            .first()
        )
        if latest and session_id:
            latest.session_id = session_id
            latest.save(update_fields=['session_id'])

    @staticmethod
    def _registration_hint(phone: str) -> dict:
        """Tell the app whether this phone already has an account (returning user)."""
        return {'isRegistered': User.objects.filter(phone=phone).exists()}

    def post(self, request):
        close_old_connections()
        phone = normalize_phone(request.data.get('phone', ''))
        if not phone:
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)

        try:
            registration_hint = self._registration_hint(phone)
            if not settings.SMS_OTP_ENABLED:
                otp = self._issue_local_otp(phone)
                logger.info('[BullWave OTP] Phone: %s | OTP: %s | SMS disabled (dev mode)', phone, otp)
                return Response(
                    {
                        'success': True,
                        'message': 'Development OTP generated without sending SMS.',
                        'otpMode': 'console',
                        'devOtp': otp,
                        **registration_hint,
                    }
                )

            live = is_live_sms()

            if settings.SMS_OTP_ENABLED and uses_2factor():
                if not uses_2factor_live():
                    return Response(
                        {
                            'detail': (
                                '2Factor SMS OTP is selected but not configured. '
                                'Set TWOFACTOR_API_KEY and TWOFACTOR_OTP_TEMPLATE in backend/.env, '
                                'then restart the server.'
                            ),
                        },
                        status=503,
                    )
                if uses_2factor_autogen():
                    try:
                        session_id = send_2factor_autogen_otp(phone)
                        self._issue_2factor_session(phone, session_id)
                    except SMSError as exc:
                        logger.error('2Factor AUTOGEN failed for %s: %s', phone, exc)
                        return Response({'detail': friendly_2factor_error(exc)}, status=503)
                    return Response(
                        {
                            'success': True,
                            'message': 'OTP sent successfully via 2Factor.',
                            'otpMode': 'sms',
                            **registration_hint,
                        }
                    )

            if settings.SMS_OTP_ENABLED and uses_twilio_verify():
                try:
                    send_otp_sms(phone, '')
                except SMSError as exc:
                    if twilio_verify_delivery_blocked(exc) and twilio_message_ready():
                        logger.warning(
                            'Twilio Verify blocked for %s; falling back to Twilio Messages',
                            phone,
                        )
                        otp = self._issue_local_otp(phone)
                        try:
                            send_otp_sms(phone, otp)
                        except SMSError as fallback_exc:
                            logger.error('Twilio Messages fallback failed for %s: %s', phone, fallback_exc)
                            return Response(
                                {'detail': friendly_twilio_error(fallback_exc)},
                                status=503,
                            )
                        return Response(
                            {
                                'success': True,
                                'message': 'OTP sent successfully.',
                                'otpMode': 'sms',
                                **registration_hint,
                            }
                        )
                    logger.error('Twilio Verify failed for %s: %s', phone, exc)
                    return Response({'detail': friendly_twilio_error(exc)}, status=503)
                return Response(
                    {
                        'success': True,
                        'message': 'OTP sent successfully.',
                        'otpMode': 'sms',
                        **registration_hint,
                    }
                )

            otp = self._issue_local_otp(phone)

            try:
                if settings.SMS_OTP_ENABLED and uses_2factor_manual():
                    session_id = send_2factor_manual_otp(phone, otp)
                    self._attach_session_to_latest_otp(phone, session_id)
                elif settings.SMS_OTP_ENABLED and uses_2factor():
                    return Response(
                        {'detail': '2Factor OTP could not be sent. Check server logs.'},
                        status=503,
                    )
                else:
                    send_otp_sms(phone, otp)
            except SMSError as exc:
                logger.error('SMS OTP failed for %s: %s', phone, exc)
                provider = resolve_sms_provider()
                if provider == '2factor':
                    detail = friendly_2factor_error(exc)
                elif provider == 'infobip':
                    detail = friendly_infobip_error(exc)
                elif provider == 'twilio':
                    detail = friendly_twilio_error(exc)
                else:
                    detail = str(exc)
                return Response({'detail': detail}, status=503)

            payload = {
                'success': True,
                'message': 'OTP sent successfully.',
                'otpMode': 'console' if not live else 'sms',
                **registration_hint,
            }
            if not live:
                payload['devOtp'] = otp
                logger.info('[BullWave OTP] Phone: %s | OTP: %s | console mode', phone, otp)
            return Response(payload)
        except DatabaseError:
            logger.exception('Database error during send-otp for %s', phone)
            return _database_unavailable_response()


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    @staticmethod
    def _verify_2factor_otp(phone: str, otp: str) -> bool:
        now = timezone.now()
        latest = (
            OTPVerification.objects.filter(
                phone=phone,
                is_used=False,
                expires_at__gte=now,
            )
            .exclude(session_id='')
            .order_by('-created_at')
            .first()
        )
        if not latest:
            return False
        try:
            verified = check_otp_2factor(latest.session_id, otp)
        except SMSError as exc:
            logger.warning('2Factor verify API failed for %s: %s', phone, exc)
            return False
        if verified:
            latest.is_used = True
            latest.save(update_fields=['is_used'])
        return verified

    @staticmethod
    def _verify_db_otp(phone: str, otp: str) -> bool:
        now = timezone.now()
        latest = (
            OTPVerification.objects.filter(phone=phone, is_used=False, expires_at__gte=now)
            .order_by('-created_at')
            .first()
        )
        if not latest or latest.otp_code != otp:
            return False
        latest.is_used = True
        latest.save(update_fields=['is_used'])
        return True

    def post(self, request):
        close_old_connections()
        phone = normalize_phone(request.data.get('phone', ''))
        otp = normalize_otp(request.data.get('otp', ''))

        if not phone:
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)
        if len(otp) != 6:
            return Response({'detail': 'Enter the 6-digit OTP.'}, status=400)

        try:
            verified = False
            if settings.SMS_OTP_ENABLED and uses_2factor():
                verified = self._verify_2factor_otp(phone, otp)
                if not verified and uses_2factor_manual():
                    verified = self._verify_db_otp(phone, otp)
            elif settings.SMS_OTP_ENABLED and uses_twilio_verify():
                try:
                    verified = check_otp_twilio_verify(phone, otp)
                except SMSError as exc:
                    logger.warning('Twilio Verify check failed for %s: %s', phone, exc)
                if not verified:
                    verified = self._verify_db_otp(phone, otp)
            else:
                verified = self._verify_db_otp(phone, otp)

            if not verified:
                return Response({'detail': 'Incorrect OTP. Please check and try again.'}, status=400)

            user, created = User.objects.get_or_create(phone=phone)
            _ensure_user_bootstrap(user, created=created)

            # Website email-first signup: attach pre-verified email after phone OTP.
            email_proof = (
                request.data.get('emailProofToken')
                or request.data.get('email_proof_token')
                or ''
            ).strip()
            if email_proof:
                try:
                    verified_email = resolve_email_proof_token(email_proof)
                    apply_verified_email_to_user(user, verified_email)
                    user.refresh_from_db()
                except EmailOtpError as exc:
                    return Response({'detail': str(exc), 'code': exc.code}, status=400)

            return _issue_auth_tokens(user, request, created=created)
        except DatabaseError:
            logger.exception('Database error during verify-otp for %s', phone)
            return _database_unavailable_response()


class DevLoginView(APIView):
    """DEBUG-only instant JWT for Flutter dev mode (no OTP / Twilio required)."""

    permission_classes = [AllowAny]

    def post(self, request):
        if not settings.DEBUG:
            return Response({'detail': 'Not available.'}, status=status.HTTP_404_NOT_FOUND)

        phone = normalize_phone(request.data.get('phone', DEV_AUTH_PHONE))
        if phone != DEV_AUTH_PHONE:
            return Response({'detail': 'Dev login is limited to the test phone number.'}, status=400)

        user, created = User.objects.get_or_create(phone=phone)
        _ensure_user_bootstrap(user, created=created)
        logger.info('Dev login issued JWT for %s', phone)
        return _issue_auth_tokens(user, request, created=created)


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={'request': request}).data)

    def patch(self, request):
        serializer = ProfileUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        try:
            for field, value in serializer.validated_data.items():
                if field == 'email':
                    new_email = normalize_email(value)
                    if new_email and not _EMAIL_REGEX.match(new_email):
                        return Response({'detail': 'Enter a valid email address.'}, status=400)
                    if new_email != normalize_email(user.email):
                        user.email_verified = False
                    user.email = new_email
                    continue
                if field == 'date_of_birth' and user_dob_verified_from_kyc(user):
                    continue
                setattr(user, field, value)
            user.save()
        except (DatabaseError, OSError) as exc:
            logger.exception('Profile update failed for user %s', user.id)
            return Response(
                {'detail': 'Could not save profile. Please try again in a moment.'},
                status=503,
            )
        return Response(UserSerializer(user, context={'request': request}).data)


class CompleteProfileView(APIView):
    """First-time profile setup after OTP — unlocks markets and stock data."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CompleteProfileSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.email_verified:
            return Response({'detail': 'Verify your email before completing profile setup.'}, status=400)

        referral_code = serializer.validated_data.pop('referral_code', '')
        profile_fields = serializer.validated_data
        profile_fields.pop('email', None)

        for field, value in profile_fields.items():
            setattr(user, field, value)
        user.has_completed_onboarding = True
        user.save()

        if referral_code and not user.referred_by_id:
            from engagement.referral_service import apply_referral_code

            apply_referral_code(user, referral_code)

        from engagement.referral_service import credit_referral_reward

        credit_referral_reward(user)

        return Response(UserSerializer(user, context={'request': request}).data)


class SendEmailOTPView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'auth:email-otp:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)

        email = normalize_email(request.data.get('email', ''))
        if not email:
            return Response({'detail': 'Enter a valid email address.'}, status=400)

        try:
            payload = send_email_otp(user=request.user, email=email)
        except EmailOtpError as exc:
            status_code = 503 if exc.code in ('email_not_configured', 'email_delivery_failed') else 400
            return Response({'detail': str(exc), 'code': exc.code}, status=status_code)

        request.user.refresh_from_db()
        payload['user'] = UserSerializer(request.user, context={'request': request}).data
        return Response(payload)


class VerifyEmailOTPView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'auth:verify-email:{request.user.id}', limit=10, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)

        email = normalize_email(request.data.get('email', ''))
        otp = normalize_otp(request.data.get('otp', ''))
        if not email:
            return Response({'detail': 'Enter a valid email address.'}, status=400)
        if len(otp) != 6:
            return Response({'detail': 'Enter the 6-digit verification code.'}, status=400)

        try:
            user = verify_email_otp(user=request.user, email=email, otp=otp)
        except EmailOtpError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        return Response(
            {
                'success': True,
                'message': 'Email verified successfully.',
                'user': UserSerializer(user, context={'request': request}).data,
            }
        )


class WebSendEmailOTPView(APIView):
    """Website signup step 1 — email OTP before phone (no JWT yet)."""

    permission_classes = [AllowAny]

    def post(self, request):
        email = normalize_email(request.data.get('email', ''))
        if not email:
            return Response({'detail': 'Enter a valid email address.'}, status=400)
        try:
            check_rate_limit(f'auth:web-email-otp:{email}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)
        try:
            payload = send_web_email_otp(email)
        except EmailOtpError as exc:
            status_code = 503 if exc.code in ('email_not_configured', 'email_delivery_failed') else 400
            return Response({'detail': str(exc), 'code': exc.code}, status=status_code)
        return Response(payload)


class WebVerifyEmailOTPView(APIView):
    """Website signup step 1b — returning users get JWT; new users get emailProofToken."""

    permission_classes = [AllowAny]

    def post(self, request):
        email = normalize_email(request.data.get('email', ''))
        otp = normalize_otp(request.data.get('otp', ''))
        if not email:
            return Response({'detail': 'Enter a valid email address.'}, status=400)
        if len(otp) != 6:
            return Response({'detail': 'Enter the 6-digit verification code.'}, status=400)
        try:
            check_rate_limit(f'auth:web-verify-email:{email}', limit=10, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)
        try:
            payload = verify_web_email_otp(email, otp)
        except EmailOtpError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        if payload.get('nextStep') in ('app', 'onboarding'):
            user = find_returning_web_user(email)
            if not user:
                return Response({'detail': 'Account not found. Continue with phone verification.'}, status=400)
            response = _issue_auth_tokens(user, request, created=False)
            data = dict(response.data)
            data.update({
                'success': True,
                'email': email,
                'nextStep': payload['nextStep'],
                'isReturningUser': True,
                'message': payload.get('message') or 'Welcome back.',
            })
            return Response(data)

        return Response(payload)


class GoogleAuthView(APIView):
    """Website — Continue with Google. Returning users get JWT; new users go to phone."""

    permission_classes = [AllowAny]

    def post(self, request):
        id_token = (
            request.data.get('idToken')
            or request.data.get('id_token')
            or request.data.get('credential')
            or ''
        )
        if not str(id_token).strip():
            return Response({'detail': 'Missing Google credential.'}, status=400)
        try:
            check_rate_limit(
                f'auth:google:{request.META.get("REMOTE_ADDR", "unknown")}',
                limit=20,
                window_seconds=300,
            )
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)
        try:
            payload = authenticate_with_google(str(id_token))
        except GoogleAuthError as exc:
            status_code = 503 if exc.code == 'not_configured' else 400
            return Response({'detail': str(exc), 'code': exc.code}, status=status_code)

        if payload.get('nextStep') in ('app', 'onboarding'):
            user = find_returning_web_user(payload['email'])
            if not user:
                return Response({'detail': 'Account not found. Continue with phone verification.'}, status=400)
            response = _issue_auth_tokens(user, request, created=False)
            data = dict(response.data)
            data.update({
                'success': True,
                'provider': 'google',
                'email': payload['email'],
                'name': payload.get('name') or user.name,
                'picture': payload.get('picture') or '',
                'nextStep': payload['nextStep'],
                'isReturningUser': True,
                'message': payload.get('message') or 'Welcome back.',
            })
            return Response(data)

        return Response(payload)


class GoogleAuthConfigView(APIView):
    """Public config so the website can show Continue with Google."""

    permission_classes = [AllowAny]

    def get(self, request):
        client_id = (getattr(settings, 'GOOGLE_OAUTH_CLIENT_ID', '') or '').strip()
        return Response({'enabled': bool(client_id), 'clientId': client_id})


class ProfileAvatarView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    _ALLOWED_TYPES = frozenset({'image/jpeg', 'image/png', 'image/webp', 'image/jpg'})

    @staticmethod
    def _detect_image_type(uploaded_file) -> str | None:
        content_type = (getattr(uploaded_file, 'content_type', '') or '').split(';')[0].strip().lower()
        if content_type in ProfileAvatarView._ALLOWED_TYPES:
            return content_type

        import mimetypes

        name = getattr(uploaded_file, 'name', '') or ''
        guessed, _ = mimetypes.guess_type(name)
        if guessed in ProfileAvatarView._ALLOWED_TYPES:
            return guessed

        if content_type not in ('', 'application/octet-stream', 'binary/octet-stream'):
            return None

        try:
            head = uploaded_file.read(16)
            uploaded_file.seek(0)
        except Exception:
            return None

        if head.startswith(b'\xff\xd8\xff'):
            return 'image/jpeg'
        if head.startswith(b'\x89PNG\r\n\x1a\n'):
            return 'image/png'
        if len(head) >= 12 and head[:4] == b'RIFF' and head[8:12] == b'WEBP':
            return 'image/webp'
        return None

    def post(self, request):
        avatar = request.FILES.get('avatar')
        if not avatar:
            return Response({'detail': 'No image file provided.'}, status=400)

        if avatar.size > 5 * 1024 * 1024:
            return Response({'detail': 'Image must be under 5 MB.'}, status=400)

        user = request.user
        try:
            ensure_media_dirs()
            normalized = normalize_avatar_upload(avatar)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except OSError:
            logger.exception('Avatar storage unavailable for user %s', user.id)
            return Response(
                {'detail': 'Could not save photo. Server storage may be full — contact support.'},
                status=503,
            )

        try:
            if user.avatar:
                user.avatar.delete(save=False)
            user.avatar = normalized
            user.avatar_url = ''
            user.save(update_fields=['avatar', 'avatar_url'])
        except (DatabaseError, OSError) as exc:
            logger.exception('Avatar save failed for user %s', user.id)
            return Response(
                {'detail': 'Could not save photo. Please try again.'},
                status=503,
            )

        return Response(UserSerializer(user, context={'request': request}).data)

    def delete(self, request):
        user = request.user
        if user.avatar:
            user.avatar.delete(save=False)
        user.avatar = None
        user.avatar_url = ''
        user.save(update_fields=['avatar', 'avatar_url'])
        return Response(UserSerializer(user, context={'request': request}).data)


class BankAccountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        account = getattr(request.user, 'bank_account', None)
        if not account:
            return Response({'detail': 'Bank account not found.'}, status=404)
        return Response(BankAccountSerializer(account).data)

    def post(self, request):
        serializer = BankAccountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        account, _ = BankAccount.objects.update_or_create(
            user=request.user,
            defaults={
                **serializer.validated_data,
                'is_verified': False,
                'verification_status': 'pending',
                'verification_provider': '',
                'verification_reference_id': '',
                'verification_message': '',
                'name_at_bank': '',
                'name_match_result': '',
                'pan_registered_name': '',
                'verified_at': None,
            },
        )
        return Response(BankAccountSerializer(account).data, status=201)


class BankVerifyView(APIView):
    """Legacy profile bank verify — delegates to the same live KYC bank step."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        account = getattr(request.user, 'bank_account', None)
        if not account:
            return Response({'detail': 'Add bank details first.'}, status=400)

        try:
            validate_ifsc(account.ifsc)
            validate_account_number(account.account_number)
        except BankValidationError as exc:
            account.verification_status = 'failed'
            account.verification_message = str(exc)
            account.save(update_fields=['verification_status', 'verification_message'])
            return Response({'detail': str(exc)}, status=400)

        from kyc.service import verify_bank_step, build_status_payload
        from services.providers.cashfree_secure_id import CashfreeSecureIdError
        from services.providers.eko_kyc import EkoKycError

        try:
            profile = verify_bank_step(
                request.user,
                account_holder_name=account.account_holder_name,
                account_number=account.account_number,
                confirm_account_number=account.account_number,
                ifsc=account.ifsc,
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except (CashfreeSecureIdError, EkoKycError) as exc:
            account.verification_status = 'failed'
            account.verification_message = str(exc)[:280]
            account.is_verified = False
            account.save(
                update_fields=['verification_status', 'verification_message', 'is_verified']
            )
            return Response({'detail': str(exc), 'code': getattr(exc, 'code', '')}, status=400)

        account.refresh_from_db()
        payload = build_status_payload(profile)
        pending_manual_review = (
            payload.get('bankReviewMode') == 'manual'
            and payload.get('bankReviewStatus') == 'pending'
        )
        return Response(
            {
                **payload,
                'success': True,
                'message': (
                    'Bank details submitted. Manual verification may take up to 24 hours.'
                    if pending_manual_review
                    else 'Bank account verified successfully.'
                ),
                'isVerified': account.is_verified,
                'provider': account.verification_provider,
                'nameAtBank': profile.name_at_bank,
                'nameMatchResult': profile.name_match_result,
                'panRegisteredName': profile.pan_name,
                'bank': profile.bank_name,
                'branch': profile.bank_branch,
            },
            status=status.HTTP_202_ACCEPTED if pending_manual_review else status.HTTP_200_OK,
        )

    def _verify_fallback(self, account, user, ifsc_data):
        """Dev-only fallback when Cashfree keys are not set."""
        if ifsc_data.get('bank') and not account.bank_name:
            account.bank_name = ifsc_data['bank'][:120]
        account.is_verified = True
        account.verification_status = 'verified'
        account.verification_provider = 'ifsc_dev'
        account.verification_message = 'Dev mode: IFSC validated only (configure Cashfree for production).'
        account.verified_at = timezone.now()
        account.save()

        if getattr(settings, 'KYC_AUTO_APPROVE', False):
            user.pan_status = User.PanStatus.VERIFIED
            user.save(update_fields=['pan_status'])

        return Response(
            {
                'success': True,
                'message': account.verification_message,
                'isVerified': True,
                'provider': 'ifsc_dev',
                'bank': ifsc_data.get('bank', account.bank_name),
                'branch': ifsc_data.get('branch', ''),
            }
        )


class KycDocumentListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        docs = request.user.kyc_documents.all()
        return Response(KycDocumentSerializer(docs, many=True).data)

    def post(self, request):
        serializer = KycDocumentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        doc, _ = KycDocument.objects.update_or_create(
            user=request.user,
            document_type=serializer.validated_data['document_type'],
            defaults={'file': serializer.validated_data['file']},
        )
        user = request.user
        if user.kyc_status == User.KycStatus.PENDING:
            user.kyc_status = User.KycStatus.IN_PROGRESS
            user.save(update_fields=['kyc_status'])
        return Response(KycDocumentSerializer(doc).data, status=201)


class KycSubmitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        required = {c[0] for c in KycDocument.DocumentType.choices}
        uploaded = set(request.user.kyc_documents.values_list('document_type', flat=True))
        if not required.issubset(uploaded):
            missing = required - uploaded
            return Response(
                {'detail': f'Missing documents: {", ".join(sorted(missing))}'},
                status=400,
            )

        user = request.user
        if getattr(settings, 'KYC_AUTO_APPROVE', True):
            user.kyc_status = User.KycStatus.COMPLETED
            notif_title = 'KYC Verified'
            notif_msg = 'Your KYC verification has been completed successfully.'
        else:
            user.kyc_status = User.KycStatus.IN_PROGRESS
            notif_title = 'KYC Submitted'
            notif_msg = 'Your documents are under review. We will notify you once verified.'
        user.save(update_fields=['kyc_status'])

        from engagement.models import Notification

        Notification.objects.create(
            user=user,
            title=notif_title,
            message=notif_msg,
            type='kyc',
        )
        return Response(KycStatusSerializer(user).data)


class KycStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(KycStatusSerializer(request.user).data)
