from django.db import migrations, models
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0017_kycprofile_bank_eko_fields'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_image',
            field=models.ImageField(blank=True, default='', upload_to='kyc/selfie/%Y/%m/'),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_status',
            field=models.CharField(
                choices=[
                    ('pending', 'Pending'),
                    ('completed', 'Completed'),
                    ('verified', 'Verified'),
                    ('rejected', 'Rejected'),
                ],
                default='pending',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_uploaded_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_review_due_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_review_note',
            field=models.CharField(blank=True, default='', max_length=500),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_reviewed_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='kycprofile',
            name='selfie_reviewed_by',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='selfie_reviews',
                to=settings.AUTH_USER_MODEL,
            ),
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
                    ('selfie', 'Selfie'),
                    ('name_match', 'Name Match'),
                ],
                max_length=20,
            ),
        ),
    ]
