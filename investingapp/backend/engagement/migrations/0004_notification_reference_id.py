from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('engagement', '0003_alter_supportticket_options_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='notification',
            name='reference_id',
            field=models.CharField(blank=True, default='', max_length=80),
        ),
    ]
