from django.db import migrations


def reset_auto_verified_emails(apps, schema_editor):
    """Only keep email_verified=True for users who completed email OTP verification."""
    User = apps.get_model('accounts', 'User')
    EmailOTPVerification = apps.get_model('accounts', 'EmailOTPVerification')

    verified_user_ids = (
        EmailOTPVerification.objects.filter(is_used=True)
        .values_list('user_id', flat=True)
        .distinct()
    )
    User.objects.exclude(id__in=verified_user_ids).update(email_verified=False)


class Migration(migrations.Migration):
    dependencies = [
        ('accounts', '0006_user_email_verified_emailotp'),
    ]

    operations = [
        migrations.RunPython(reset_auto_verified_emails, migrations.RunPython.noop),
    ]
