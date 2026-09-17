"""AWS fallback email OTP until the full accounts email module is deployed."""

from __future__ import annotations

import random
import re

from django.conf import settings
from django.core.cache import cache
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

_EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')


def _norm(email: str) -> str:
    return (email or '').strip().lower()


def _otp() -> str:
    return f'{random.randint(100000, 999999):06d}'


def _user_payload(user, *, email: str, verified: bool) -> dict:
    return {
        'id': str(user.pk),
        'phone': getattr(user, 'phone', ''),
        'name': getattr(user, 'name', ''),
        'email': email,
        'emailVerified': verified,
        'hasCompletedOnboarding': bool(getattr(user, 'has_completed_onboarding', False)),
    }


class SendEmailOTPView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        email = _norm(request.data.get('email', ''))
        if not _EMAIL_RE.match(email):
            return Response({'detail': 'Enter a valid email address.'}, status=400)
        code = _otp()
        ttl = int(getattr(settings, 'OTP_EXPIRY_MINUTES', 5)) * 60
        cache.set(f'email-otp:{request.user.pk}:{email}', code, timeout=ttl)
        request.user.email = email
        try:
            if hasattr(request.user, 'email_verified'):
                request.user.email_verified = False
                request.user.save(update_fields=['email', 'email_verified'])
            else:
                request.user.save(update_fields=['email'])
        except Exception:
            request.user.save()
        print(f'[BullWave EMAIL OTP] {email} {code}', flush=True)
        sent = False
        try:
            from kyc.notifications import email_delivery_chain, send_plain_email

            if email_delivery_chain():
                send_plain_email(
                    to_email=email,
                    subject='Your BullWave email verification code',
                    text_body=(
                        f'Your BullWave verification code is {code}.\n\n'
                        f'It expires in {int(getattr(settings, "OTP_EXPIRY_MINUTES", 5))} minutes.'
                    ),
                )
                sent = True
        except Exception as exc:
            print(f'[BullWave EMAIL OTP] send failed: {exc}', flush=True)
        payload = {
            'success': True,
            'email': email,
            'user': _user_payload(request.user, email=email, verified=False),
        }
        if sent:
            payload['message'] = 'Verification code sent to your email.'
            payload['otpMode'] = 'email'
        else:
            payload['message'] = 'Development email OTP generated without sending mail.'
            payload['otpMode'] = 'console'
            payload['devOtp'] = code
        return Response(payload)


class VerifyEmailOTPView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        email = _norm(request.data.get('email', ''))
        otp = ''.join(ch for ch in str(request.data.get('otp') or '') if ch.isdigit())
        if not _EMAIL_RE.match(email):
            return Response({'detail': 'Enter a valid email address.'}, status=400)
        if len(otp) != 6:
            return Response({'detail': 'Enter the 6-digit verification code.'}, status=400)
        expected = cache.get(f'email-otp:{request.user.pk}:{email}')
        if not expected:
            return Response({'detail': 'Verification code expired. Request a new code.'}, status=400)
        if expected != otp:
            return Response({'detail': 'Incorrect verification code. Please try again.'}, status=400)
        cache.delete(f'email-otp:{request.user.pk}:{email}')
        request.user.email = email
        try:
            if hasattr(request.user, 'email_verified'):
                request.user.email_verified = True
                request.user.save(update_fields=['email', 'email_verified'])
            else:
                request.user.save(update_fields=['email'])
        except Exception:
            request.user.save()
        return Response(
            {
                'success': True,
                'message': 'Email verified successfully.',
                'user': _user_payload(request.user, email=email, verified=True),
            }
        )
