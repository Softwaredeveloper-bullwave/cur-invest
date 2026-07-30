from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('kyc', '0015_bankverificationrequest'),
    ]

    operations = [
        migrations.AddField(
            model_name='bankverificationrequest',
            name='upi_vpa',
            field=models.CharField(blank=True, default='', max_length=120),
        ),
        migrations.AddField(
            model_name='bankverificationrequest',
            name='upi_mobile',
            field=models.CharField(blank=True, default='', max_length=15),
        ),
    ]
