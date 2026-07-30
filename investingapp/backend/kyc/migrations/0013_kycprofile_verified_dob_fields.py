from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('kyc', '0012_kycprofile_bank_verification_method'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='pan_dob',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_dob',
            field=models.DateField(blank=True, null=True),
        ),
    ]
