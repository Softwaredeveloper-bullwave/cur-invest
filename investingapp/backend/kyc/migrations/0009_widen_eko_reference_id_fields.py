# Generated manually — widens reference/otp-ref CharFields that were too
# short for Eko's real tokens. Confirmed in production: a real otp_ref_id
# ("HiRXSQ6wAFOV3pilh3evP4A...") is 96 characters, but these columns were
# capped at max_length=64, so Postgres raised a hard DataError (an
# unhandled HTTP 500) the moment a real token was saved.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0008_kycprofile_aadhaar_sender_fields'),
    ]

    operations = [
        migrations.AlterField(
            model_name='kycprofile',
            name='aadhaar_otp_ref_id',
            field=models.CharField(blank=True, default='', max_length=512),
        ),
        migrations.AlterField(
            model_name='kycprofile',
            name='aadhaar_reference_id',
            field=models.CharField(blank=True, default='', max_length=512),
        ),
        migrations.AlterField(
            model_name='kycprofile',
            name='aadhaar_sender_otp_ref_id',
            field=models.CharField(blank=True, default='', max_length=512),
        ),
        migrations.AlterField(
            model_name='kycprofile',
            name='bank_reference_id',
            field=models.CharField(blank=True, default='', max_length=512),
        ),
    ]
