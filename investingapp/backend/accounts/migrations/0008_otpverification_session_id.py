from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('accounts', '0007_reset_unverified_email_flags'),
    ]

    operations = [
        migrations.AddField(
            model_name='otpverification',
            name='session_id',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
    ]
