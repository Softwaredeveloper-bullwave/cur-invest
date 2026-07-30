from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0013_kycprofile_verified_dob_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='upi_failure_reason',
            field=models.CharField(blank=True, default='', max_length=280),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_mobile',
            field=models.CharField(blank=True, default='', max_length=15),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_name',
            field=models.CharField(blank=True, default='', max_length=120),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_name_match_score',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=5),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_reference_id',
            field=models.CharField(blank=True, default='', max_length=512),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_status',
            field=models.CharField(
                choices=[('pending', 'Pending'), ('verified', 'Verified'), ('failed', 'Failed')],
                default='pending',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_vpa',
            field=models.CharField(blank=True, default='', max_length=120),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='upi_verified_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='verificationauditlog',
            name='step',
            field=models.CharField(
                choices=[
                    ('pan', 'PAN'),
                    ('aadhaar', 'Aadhaar'),
                    ('bank', 'Bank'),
                    ('upi', 'UPI'),
                    ('name_match', 'Name Match'),
                ],
                max_length=20,
            ),
        ),
    ]
