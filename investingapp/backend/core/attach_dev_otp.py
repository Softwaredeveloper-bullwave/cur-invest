"""Attach the latest DB OTP to send-otp JSON when SMS is in console/dev mode."""

from __future__ import annotations

import json

from django.http import HttpResponse


class AttachDevOtpMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        try:
            return self._attach(request, response)
        except Exception:
            return response

    def _attach(self, request, response):
        if request.method != 'POST':
            return response
        path = request.path.rstrip('/')
        if not path.endswith('/auth/send-otp'):
            return response
        try:
            payload = json.loads(response.content.decode() or '{}')
        except Exception:
            return response
        if not isinstance(payload, dict) or payload.get('devOtp'):
            return response

        try:
            body = json.loads(request.body.decode() or '{}')
        except Exception:
            body = {}
        digits = ''.join(ch for ch in str(body.get('phone') or '') if ch.isdigit())[-10:]
        if len(digits) != 10:
            return response

        from accounts.models import OTPVerification

        row = (
            OTPVerification.objects.filter(phone__endswith=digits, is_used=False)
            .order_by('-created_at')
            .first()
        )
        if not row or not row.otp_code:
            return response

        payload['devOtp'] = str(row.otp_code)
        payload['otpMode'] = 'console'
        new = HttpResponse(
            json.dumps(payload),
            status=response.status_code,
            content_type='application/json',
        )
        for key, value in response.items():
            if key.lower() not in ('content-type', 'content-length'):
                new[key] = value
        return new
