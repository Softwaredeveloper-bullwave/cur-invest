from django.db import migrations, models


def remove_verified_plaintext(apps, schema_editor):
    KycProfile = apps.get_model('kyc', 'KycProfile')
    for profile in KycProfile.objects.exclude(aadhaar_number='').iterator():
        value = profile.aadhaar_number.strip()
        if len(value) == 12 and value.isdigit():
            profile.aadhaar_last4 = value[-4:]
            if profile.aadhaar_status == 'verified':
                profile.aadhaar_number = ''
            profile.save(update_fields=['aadhaar_last4', 'aadhaar_number'])


class Migration(migrations.Migration):
    dependencies = [
        ('kyc', '0009_widen_eko_reference_id_fields'),
    ]

    operations = [
        migrations.AlterField(
            model_name='kycprofile',
            name='aadhaar_number',
            field=models.CharField(blank=True, default='', max_length=255),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='aadhaar_last4',
            field=models.CharField(blank=True, default='', max_length=4),
        ),
        migrations.AlterField(
            model_name='verificationauditlog',
            name='step',
            field=models.CharField(
                choices=[
                    ('pan', 'PAN'),
                    ('aadhaar', 'Aadhaar'),
                    ('bank', 'Bank'),
                    ('name_match', 'Name Match'),
                ],
                max_length=20,
            ),
        ),
        migrations.RunPython(remove_verified_plaintext, migrations.RunPython.noop),
    ]
