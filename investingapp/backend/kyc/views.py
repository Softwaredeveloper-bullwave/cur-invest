import logging

from django.http import HttpResponse
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.views import SendOTPView, VerifyOTPView

from .rate_limit import RateLimitExceeded, check_rate_limit, rate_limit_response
from .serializers import (
    SendAadhaarOtpSerializer,
    VerifyAadhaarOtpSerializer,
    VerifyBankSerializer,
    VerifyPanSerializer,
    VerifySenderOtpSerializer,
    VerifyUpiSerializer,
)
from .service import (
    ProviderError,
    build_status_payload,
    check_aadhaar_digilocker_step,
    digilocker_app_return_url,
    get_or_create_profile,
    name_match_step,
    record_digilocker_callback,
    resend_aadhaar_otp_step,
    resend_sender_otp_step,
    send_aadhaar_otp_step,
    start_aadhaar_digilocker_step,
    verify_aadhaar_otp_step,
    verify_bank_step,
    verify_pan_step,
    verify_sender_otp_step,
    verify_upi_step,
)
from .selfie_service import SelfieError, upload_selfie

logger = logging.getLogger('bullwave.kyc')


class SendOtpAliasView(SendOTPView):
    """Alias: POST /api/v1/send-otp/"""


class VerifyOtpAliasView(VerifyOTPView):
    """Alias: POST /api/v1/verify-otp/"""


class VerifyPanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:pan:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        serializer = VerifyPanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_pan_step(
                request.user,
                data['pan_number'],
                data.get('holder_name', ''),
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            body = {'detail': str(exc), 'code': getattr(exc, 'code', '') or ''}
            eko_meta = getattr(exc, 'eko_meta', None)
            if eko_meta:
                body['eko'] = eko_meta
            return Response(body, status=400)

        payload = build_status_payload(profile)
        response = {
            **payload,
            'success': True,
            'message': 'PAN verified successfully.',
        }
        if (profile.pan_reference_id or '').startswith(('sandbox-', 'eko-sandbox-')):
            response['devBypass'] = True
            response['message'] = (
                'PAN accepted in sandbox dev mode. Real PAN verification requires '
                'live provider keys (see KYC_PROVIDER in .env).'
            )
        return Response(response)


class StartAadhaarDigiLockerView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:digilocker-start:{request.user.id}', limit=3, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)
        try:
            profile = start_aadhaar_digilocker_step(request.user)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)
        return Response(
            {
                **build_status_payload(profile),
                'success': True,
                'message': 'Continue securely in DigiLocker to share your Aadhaar.',
            }
        )


class CheckAadhaarDigiLockerView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:digilocker-status:{request.user.id}', limit=20, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)
        verification_id = (
            request.data.get('verification_id')
            or request.data.get('verificationId')
            or ''
        )
        try:
            profile = check_aadhaar_digilocker_step(
                request.user,
                verification_id=str(verification_id or '').strip(),
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)
        verified = profile.aadhaar_status == 'verified'
        return Response(
            {
                **build_status_payload(profile),
                'success': verified,
                'message': (
                    'Aadhaar verified successfully through DigiLocker.'
                    if verified
                    else 'DigiLocker verification is still pending.'
                ),
            }
        )


class AadhaarDigiLockerCallbackView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, state):
        verification_id = (
            request.query_params.get('verification_id')
            or request.query_params.get('verificationId')
            or ''
        )
        accepted = record_digilocker_callback(
            state=state,
            verification_id=verification_id,
        )
        app_return_url = digilocker_app_return_url(verification_id=verification_id) if accepted else ''
        if app_return_url:
            from django.shortcuts import redirect

            return redirect(app_return_url)

        title = 'DigiLocker complete' if accepted else 'Verification link expired'
        message = (
            'You can close this tab and return to the BullWave app. '
            'Tap “Check verification status” on the Aadhaar screen.'
            if accepted
            else 'This verification link is invalid or expired. Start again from the BullWave app.'
        )
        return HttpResponse(
            '<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{title}</title>'
            '<style>body{font-family:system-ui,-apple-system,sans-serif;background:#0c0c0c;color:#f5f5f5;'
            'display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:24px;}'
            '.card{max-width:420px;background:#171717;border:1px solid #2a2a2a;border-radius:18px;padding:28px;text-align:center;}'
            'h2{margin:0 0 12px;font-size:22px;}p{line-height:1.55;color:#bdbdbd;margin:0 0 18px;}'
            '.badge{display:inline-block;background:#c8ff001a;color:#c8ff00;border:1px solid #c8ff0040;'
            'padding:8px 14px;border-radius:999px;font-size:13px;font-weight:700;}</style></head><body>'
            '<div class="card">'
            f'<div class="badge">BullWave KYC</div>'
            f'<h2>{title}</h2><p>{message}</p>'
            '</div>'
            '<script>setTimeout(function(){try{window.close();}catch(e){}},2500);</script>'
            '</body></html>'
        )


# ---------------------------------------------------------------------------
# Legacy Eko Aadhaar OTP views — superseded by DigiLocker (see urls.py).
# Kept for reference; not registered in urlpatterns.
# ---------------------------------------------------------------------------

class SendAadhaarOtpView(APIView):
    """Step 1 of Aadhaar eKYC — send OTP to the Aadhaar-linked mobile number."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:aadhaar-otp:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        serializer = SendAadhaarOtpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = send_aadhaar_otp_step(request.user, data['aadhaar_number'])
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        payload = build_status_payload(profile)
        if payload.get('aadhaarVerified'):
            message = 'Aadhaar is already verified.'
        elif payload.get('aadhaarRequiresSenderOtp'):
            message = 'Enter the verification code sent to your mobile number to continue.'
        else:
            message = 'OTP sent to your Aadhaar-linked mobile number.'
        response = {
            **payload,
            'success': True,
            'message': message,
        }
        if (profile.aadhaar_otp_ref_id or profile.aadhaar_sender_otp_ref_id or '').startswith('eko-sandbox-'):
            response['devBypass'] = True
            response['message'] = 'Aadhaar OTP accepted in sandbox dev mode.'
        return Response(response)


class ResendSenderOtpView(APIView):
    """Request a fresh mobile-verification code when the pending one expired."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:sender-otp-resend:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        try:
            profile = resend_sender_otp_step(request.user)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        payload = build_status_payload(profile)
        return Response(
            {
                **payload,
                'success': True,
                'message': 'A new verification code has been sent to your mobile number.',
            }
        )


class ResendAadhaarOtpView(APIView):
    """Request a fresh OTP for the active Aadhaar verification transaction."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:aadhaar-otp-resend:{request.user.id}', limit=3, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        try:
            profile = resend_aadhaar_otp_step(request.user)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        return Response(
            {
                **build_status_payload(profile),
                'success': True,
                'message': 'A new OTP was sent to your Aadhaar-linked mobile number.',
            }
        )


class VerifySenderOtpView(APIView):
    """Confirm Eko's one-time sender-enrollment OTP, then immediately trigger
    the real Aadhaar OTP now that the mobile number is onboarded."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:sender-otp:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        serializer = VerifySenderOtpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_sender_otp_step(request.user, data['otp'])
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        payload = build_status_payload(profile)
        return Response(
            {
                **payload,
                'success': True,
                'message': 'Mobile verified. OTP sent to your Aadhaar-linked mobile number.',
            }
        )


class VerifyAadhaarOtpView(APIView):
    """Step 2 of Aadhaar eKYC — verify the OTP."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:aadhaar-verify:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        serializer = VerifyAadhaarOtpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_aadhaar_otp_step(request.user, data['otp'])
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        payload = build_status_payload(profile)
        return Response(
            {
                **payload,
                'success': True,
                'message': 'Aadhaar verified successfully.',
            }
        )


class VerifyBankView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:bank:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        serializer = VerifyBankSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_bank_step(request.user, **data)
        except ValueError as exc:
            return Response(
                {'success': False, 'verified': False, 'message': str(exc)},
                status=400,
            )
        except ProviderError as exc:
            return Response(
                {
                    'success': False,
                    'verified': False,
                    'message': str(exc),
                },
                status=400,
            )

        payload = build_status_payload(profile)
        manual_mode = payload.get('bankReviewMode') == 'manual'
        pending_manual_review = payload.get('paymentReviewPending') is True

        if manual_mode or pending_manual_review:
            return Response(
                {
                    **payload,
                    'success': True,
                    'verified': False,
                    'message': (
                        'Bank details saved. Continue to UPI verification.'
                        if manual_mode and payload.get('bankDraftReady')
                        else 'Bank details submitted. Manual verification may take up to 24 hours.'
                    ),
                },
                status=status.HTTP_200_OK,
            )

        return Response(
            {
                'success': True,
                'verified': True,
                'bank_name': profile.bank_name,
                'name_at_bank': profile.name_at_bank,
                'reference_id': profile.bank_reference_id,
                'message': 'Bank account verified successfully.',
            },
            status=status.HTTP_200_OK,
        )


class VerifyUpiView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:upi:{request.user.id}', limit=8, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        serializer = VerifyUpiSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_upi_step(request.user, **data)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ProviderError as exc:
            body = {'detail': str(exc), 'code': getattr(exc, 'code', '') or ''}
            eko_meta = getattr(exc, 'eko_meta', None)
            if eko_meta:
                body['eko'] = eko_meta
            return Response(body, status=400)

        payload = build_status_payload(profile)
        pending_manual_review = payload.get('paymentReviewPending') is True
        return Response(
            {
                **payload,
                'success': True,
                'message': (
                    'Bank account and UPI ID submitted for manual review. Verification may take up to 24 hours.'
                    if pending_manual_review
                    else 'UPI ID verified successfully.'
                ),
            },
            status=status.HTTP_202_ACCEPTED if pending_manual_review else status.HTTP_200_OK,
        )


class NameMatchView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:match:{request.user.id}', limit=10, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        try:
            profile = name_match_step(request.user)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)

        payload = build_status_payload(profile)
        if not profile.name_match_passed:
            return Response(
                {
                    **payload,
                    'success': False,
                    'message': 'Name on PAN does not match bank account holder name.',
                },
                status=400,
            )

        return Response(
            {
                **payload,
                'success': True,
                'message': 'Name match verified.',
            }
        )


class KycStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = get_or_create_profile(request.user)
        return Response(build_status_payload(profile))


class UploadSelfieView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:selfie:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return rate_limit_response(exc)

        image = request.FILES.get('selfie') or request.FILES.get('selfie_image')
        try:
            profile = upload_selfie(request.user, image)
        except SelfieError as exc:
            return Response({'detail': str(exc)}, status=400)
        except Exception:
            logger.exception('Selfie upload failed for user %s', request.user_id)
            return Response({'detail': 'Could not upload selfie. Please try again.'}, status=500)

        payload = build_status_payload(profile)
        selfie_url = payload.get('selfieUrl') or ''
        if selfie_url and selfie_url.startswith('/'):
            selfie_url = request.build_absolute_uri(selfie_url)
            payload = {**payload, 'selfieUrl': selfie_url}

        return Response(
            {
                **payload,
                'success': True,
                'message': 'Selfie uploaded successfully.',
            },
            status=status.HTTP_201_CREATED,
        )
