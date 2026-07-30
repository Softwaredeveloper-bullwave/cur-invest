import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('kyc', '0014_kycprofile_upi_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='BankVerificationRequest',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('account_holder_name', models.CharField(blank=True, default='', max_length=120)),
                ('account_number', models.CharField(max_length=20)),
                ('ifsc', models.CharField(max_length=11)),
                ('bank_name', models.CharField(blank=True, default='', max_length=120)),
                ('bank_branch', models.CharField(blank=True, default='', max_length=120)),
                (
                    'status',
                    models.CharField(
                        choices=[
                            ('pending', 'Pending'),
                            ('approved', 'Approved'),
                            ('rejected', 'Rejected'),
                            ('superseded', 'Superseded'),
                        ],
                        default='pending',
                        max_length=20,
                    ),
                ),
                ('review_note', models.CharField(blank=True, default='', max_length=500)),
                ('submitted_at', models.DateTimeField(auto_now_add=True)),
                ('review_due_at', models.DateTimeField()),
                ('reviewed_at', models.DateTimeField(blank=True, null=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                (
                    'reviewed_by',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='bank_verification_reviews',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='bank_verification_requests',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={'ordering': ['-submitted_at']},
        ),
        migrations.AddIndex(
            model_name='bankverificationrequest',
            index=models.Index(fields=['status', 'review_due_at'], name='kyc_bankver_status_24f079_idx'),
        ),
        migrations.AddIndex(
            model_name='bankverificationrequest',
            index=models.Index(fields=['user', 'submitted_at'], name='kyc_bankver_user_id_a459f4_idx'),
        ),
    ]
