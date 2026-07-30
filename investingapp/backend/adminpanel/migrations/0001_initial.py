import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [migrations.swappable_dependency(settings.AUTH_USER_MODEL)]

    operations = [
        migrations.CreateModel(
            name='AdminActionAudit',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('action', models.CharField(max_length=80)),
                ('target_type', models.CharField(max_length=80)),
                ('target_id', models.CharField(max_length=80)),
                ('summary', models.CharField(blank=True, default='', max_length=500)),
                ('metadata', models.JSONField(blank=True, default=dict)),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                (
                    'actor',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='admin_actions',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.AddIndex(
            model_name='adminactionaudit',
            index=models.Index(fields=['actor', 'created_at'], name='adminpanel_actor_i_827c40_idx'),
        ),
        migrations.AddIndex(
            model_name='adminactionaudit',
            index=models.Index(fields=['target_type', 'target_id'], name='adminpanel_target__cedd64_idx'),
        ),
    ]
