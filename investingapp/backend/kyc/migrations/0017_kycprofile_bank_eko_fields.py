from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0016_bankverificationrequest_upi_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='bank_utr',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='bank_account_status',
            field=models.CharField(blank=True, default='', max_length=32),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='bank_account_status_code',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
    ]
