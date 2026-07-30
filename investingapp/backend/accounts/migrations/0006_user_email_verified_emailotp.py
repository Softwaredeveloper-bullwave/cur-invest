from django.db import migrations, models


def mark_existing_emails_verified(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    User.objects.filter(
        email__gt='',
        has_completed_onboarding=True,
    ).update(email_verified=True)


class Migration(migrations.Migration):
    dependencies = [
        ('accounts', '0005_user_fno_status'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='email_verified',
            field=models.BooleanField(default=False),
        ),
        migrations.CreateModel(
            name='EmailOTPVerification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(db_index=True, max_length=254)),
                ('otp_code', models.CharField(max_length=6)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('expires_at', models.DateTimeField()),
                ('is_used', models.BooleanField(default=False)),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name='email_otp_requests',
                        to='accounts.user',
                    ),
                ),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.RunPython(mark_existing_emails_verified, migrations.RunPython.noop),
    ]
