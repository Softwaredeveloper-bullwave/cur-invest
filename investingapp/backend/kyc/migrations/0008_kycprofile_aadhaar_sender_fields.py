# Generated manually to match Django 6.0.7 migration style — mirrors the
# AddField pattern used by 0007_kycprofile_aadhaar_fields.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0007_kycprofile_aadhaar_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_sender_enrolled',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_sender_otp_ref_id',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
    ]
