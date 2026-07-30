from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('kyc', '0011_kycprofile_digilocker_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='bank_verification_method',
            field=models.CharField(blank=True, default='', max_length=20),
        ),
    ]
