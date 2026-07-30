from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('kyc', '0010_secure_aadhaar_number'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_digilocker_url',
            field=models.URLField(blank=True, default='', max_length=1000),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_digilocker_client_ref_id',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_digilocker_verification_id',
            field=models.CharField(blank=True, default='', max_length=255),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_digilocker_state_digest',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_digilocker_started_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
