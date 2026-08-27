from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('crypto', '0002_crypto_news_image_url'),
    ]

    operations = [
        migrations.AddField(
            model_name='usermarketpreference',
            name='forex_market_enabled',
            field=models.BooleanField(default=False),
        ),
    ]
