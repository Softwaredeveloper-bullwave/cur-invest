from rest_framework import serializers

from core.serializers import CamelCaseSerializer

from .models import KycProfile, VerificationAuditLog


_VERHOEFF_D = (
    (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    (1, 2, 3, 4, 0, 6, 7, 8, 9, 5),
    (2, 3, 4, 0, 1, 7, 8, 9, 5, 6),
    (3, 4, 0, 1, 2, 8, 9, 5, 6, 7),
    (4, 0, 1, 2, 3, 9, 5, 6, 7, 8),
    (5, 9, 8, 7, 6, 0, 4, 3, 2, 1),
    (6, 5, 9, 8, 7, 1, 0, 4, 3, 2),
    (7, 6, 5, 9, 8, 2, 1, 0, 4, 3),
    (8, 7, 6, 5, 9, 3, 2, 1, 0, 4),
    (9, 8, 7, 6, 5, 4, 3, 2, 1, 0),
)
_VERHOEFF_P = (
    (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    (1, 5, 7, 6, 2, 8, 3, 0, 9, 4),
    (5, 8, 0, 3, 7, 9, 6, 1, 4, 2),
    (8, 9, 1, 6, 0, 4, 3, 5, 2, 7),
    (9, 4, 5, 3, 1, 2, 6, 8, 7, 0),
    (4, 2, 8, 6, 5, 7, 3, 9, 0, 1),
    (2, 7, 9, 3, 8, 0, 6, 4, 1, 5),
    (7, 0, 4, 6, 9, 1, 3, 2, 5, 8),
)


def _valid_aadhaar_checksum(value: str) -> bool:
    checksum = 0
    for index, digit in enumerate(reversed(value)):
        checksum = _VERHOEFF_D[checksum][_VERHOEFF_P[index % 8][int(digit)]]
    return checksum == 0


class VerifyPanSerializer(CamelCaseSerializer):
    pan_number = serializers.CharField(max_length=10, min_length=10)
    holder_name = serializers.CharField(max_length=120, required=False, allow_blank=True)


class VerifyBankSerializer(CamelCaseSerializer):
    account_holder_name = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
        default='',
    )
    account_number = serializers.CharField(max_length=20, min_length=9)
    confirm_account_number = serializers.CharField(max_length=20, min_length=9)
    ifsc = serializers.CharField(max_length=11, min_length=11)
    # Optional — only required by the Eko provider to create a KYC customer
    # profile before penny-drop verification. Ignored by Cashfree.
    address_line = serializers.CharField(max_length=200, required=False, allow_blank=True, default='')
    address_state = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    address_pincode = serializers.CharField(max_length=10, required=False, allow_blank=True, default='')
    address_district = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    address_area = serializers.CharField(max_length=120, required=False, allow_blank=True, default='')


class VerifyUpiSerializer(CamelCaseSerializer):
    upi_vpa = serializers.CharField(max_length=120, min_length=3)
    recipient_mobile = serializers.CharField(max_length=15, required=False, allow_blank=True, default='')
    latlong = serializers.CharField(max_length=40, required=False, allow_blank=True, default='')

    def validate_upi_vpa(self, value):
        vpa = value.strip().lower()
        if '@' not in vpa or vpa.startswith('@') or vpa.endswith('@'):
            raise serializers.ValidationError('Enter a valid UPI ID (e.g. name@upi).')
        local, handle = vpa.split('@', 1)
        if not local or not handle:
            raise serializers.ValidationError('Enter a valid UPI ID (e.g. name@upi).')
        return vpa


class SendAadhaarOtpSerializer(CamelCaseSerializer):
    aadhaar_number = serializers.CharField(max_length=12, min_length=12)

    def validate_aadhaar_number(self, value):
        if not value.isdigit() or not _valid_aadhaar_checksum(value):
            raise serializers.ValidationError('Enter a valid Aadhaar number.')
        return value


class VerifyAadhaarOtpSerializer(CamelCaseSerializer):
    otp = serializers.RegexField(r'^\d{4,6}$')


class VerifySenderOtpSerializer(CamelCaseSerializer):
    otp = serializers.RegexField(r'^\d{4,6}$')


class KycStatusSerializer(CamelCaseSerializer):
    mobile_verified = serializers.BooleanField()
    pan_verified = serializers.BooleanField()
    bank_verified = serializers.BooleanField()
    name_match_passed = serializers.BooleanField()
    overall_status = serializers.CharField()
    pan_number_masked = serializers.CharField()
    pan_name = serializers.CharField()
    pan_status = serializers.CharField()
    bank_name = serializers.CharField()
    bank_branch = serializers.CharField()
    account_holder_name = serializers.CharField()
    bank_account_masked = serializers.CharField()
    ifsc = serializers.CharField()
    bank_status = serializers.CharField()
    name_at_bank = serializers.CharField()
    name_match_result = serializers.CharField()
    name_match_score = serializers.FloatField()
    verified_at = serializers.CharField(allow_null=True)
