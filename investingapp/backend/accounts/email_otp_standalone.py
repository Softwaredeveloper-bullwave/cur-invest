"""Compatibility aliases for older AWS-only URL wiring.

Use accounts.views.SendEmailOTPView. This module exists so a leftover
`from .email_otp_standalone import ...` on the server still loads the
real Gmail SMTP email OTP views after git pull.
"""

from .views import SendEmailOTPView, VerifyEmailOTPView

__all__ = ['SendEmailOTPView', 'VerifyEmailOTPView']
