# Generated manually to match Django 6.0.7 migration style — mirrors the
# AddField pattern used by earlier auto-generated KYC migrations.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0006_rename_kyc_fnoelig_status_created_idx_kyc_fnoelig_status_25c40d_idx_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_number',
            field=models.CharField(blank=True, default='', max_length=12),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_name',
            field=models.CharField(blank=True, default='', max_length=120),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_status',
            field=models.CharField(
                choices=[('pending', 'Pending'), ('verified', 'Verified'), ('failed', 'Failed')],
                default='pending',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_otp_ref_id',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_reference_id',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_failure_reason',
            field=models.CharField(blank=True, default='', max_length=280),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_otp_sent_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_verified_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
