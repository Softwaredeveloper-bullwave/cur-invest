from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('crypto', '0001_initial_crypto_markets'),
    ]

    operations = [
        migrations.AlterField(
            model_name='cryptonewsarticle',
            name='image_url',
            field=models.CharField(blank=True, default='', max_length=1000),
        ),
    ]
