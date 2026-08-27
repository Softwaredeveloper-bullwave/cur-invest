from django.db import migrations, models
import django.db.models.deletion
import uuid
from decimal import Decimal
from django.conf import settings


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='ForexPair',
            fields=[
                ('id', models.CharField(max_length=16, primary_key=True, serialize=False)),
                ('base_currency', models.CharField(max_length=8)),
                ('quote_currency', models.CharField(max_length=8)),
                ('symbol', models.CharField(db_index=True, max_length=16)),
                ('name', models.CharField(max_length=120)),
                ('category', models.CharField(db_index=True, default='Majors', max_length=32)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={'ordering': ['category', 'symbol']},
        ),
        migrations.CreateModel(
            name='ForexMarketSnapshot',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('current_price', models.DecimalField(decimal_places=6, default=Decimal('0'), max_digits=18)),
                ('price_change_24h', models.DecimalField(decimal_places=6, default=Decimal('0'), max_digits=18)),
                ('price_change_percentage_24h', models.DecimalField(decimal_places=4, default=Decimal('0'), max_digits=12)),
                ('high_24h', models.DecimalField(blank=True, decimal_places=6, max_digits=18, null=True)),
                ('low_24h', models.DecimalField(blank=True, decimal_places=6, max_digits=18, null=True)),
                ('sparkline_7d', models.JSONField(blank=True, default=list)),
                ('provider', models.CharField(blank=True, default='', max_length=40)),
                ('fetched_at', models.DateTimeField(blank=True, null=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('pair', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='snapshot', to='forex.forexpair')),
            ],
        ),
        migrations.CreateModel(
            name='ForexWatchlistItem',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('added_at', models.DateTimeField(auto_now_add=True)),
                ('pair', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='watchers', to='forex.forexpair')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='forex_watchlist_items', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-added_at'], 'unique_together': {('user', 'pair')}},
        ),
        migrations.CreateModel(
            name='ForexPracticeWallet',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('balance', models.DecimalField(decimal_places=2, default=Decimal('100000'), max_digits=14)),
                ('currency', models.CharField(default='INR', max_length=8)),
                ('last_refilled_at', models.DateTimeField(blank=True, null=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='forex_practice_wallet', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='ForexHolding',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('quantity', models.DecimalField(decimal_places=6, default=Decimal('0'), max_digits=18)),
                ('avg_price', models.DecimalField(decimal_places=6, default=Decimal('0'), max_digits=18)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('pair', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='holdings', to='forex.forexpair')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='forex_holdings', to=settings.AUTH_USER_MODEL)),
            ],
            options={'unique_together': {('user', 'pair')}},
        ),
        migrations.CreateModel(
            name='ForexTransaction',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('tx_type', models.CharField(choices=[('BUY', 'Buy'), ('SELL', 'Sell')], max_length=16)),
                ('quantity', models.DecimalField(decimal_places=6, default=Decimal('0'), max_digits=18)),
                ('price', models.DecimalField(decimal_places=6, default=Decimal('0'), max_digits=18)),
                ('total_value', models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=18)),
                ('fees', models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=14)),
                ('currency', models.CharField(default='INR', max_length=8)),
                ('exchange', models.CharField(blank=True, default='PAPER', max_length=64)),
                ('status', models.CharField(choices=[('Pending', 'Pending'), ('Completed', 'Completed'), ('Failed', 'Failed'), ('Cancelled', 'Cancelled')], default='Completed', max_length=20)),
                ('is_paper', models.BooleanField(default=True)),
                ('notes', models.CharField(blank=True, default='', max_length=255)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('pair', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name='transactions', to='forex.forexpair')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='forex_transactions', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='ForexNewsArticle',
            fields=[
                ('id', models.CharField(max_length=64, primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=400)),
                ('summary', models.TextField(blank=True, default='')),
                ('image_url', models.CharField(blank=True, default='', max_length=1000)),
                ('source', models.CharField(max_length=120)),
                ('published_at', models.DateTimeField(db_index=True)),
                ('category', models.CharField(db_index=True, default='Market Analysis', max_length=40)),
                ('related_pairs', models.JSONField(blank=True, default=list)),
                ('external_url', models.URLField(max_length=500)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={'ordering': ['-published_at']},
        ),
        migrations.CreateModel(
            name='ForexNotificationPreference',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('price_alerts', models.BooleanField(default=True)),
                ('news_alerts', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='forex_notification_preference', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='ForexProviderHealth',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('service', models.CharField(max_length=40, unique=True)),
                ('status', models.CharField(choices=[('HEALTHY', 'Healthy'), ('DEGRADED', 'Degraded'), ('DOWN', 'Down'), ('UNKNOWN', 'Unknown')], default='UNKNOWN', max_length=16)),
                ('provider_name', models.CharField(blank=True, default='', max_length=64)),
                ('last_success_at', models.DateTimeField(blank=True, null=True)),
                ('last_error_at', models.DateTimeField(blank=True, null=True)),
                ('last_error_message', models.CharField(blank=True, default='', max_length=500)),
                ('avg_response_ms', models.PositiveIntegerField(blank=True, null=True)),
                ('rate_limit_hits', models.PositiveIntegerField(default=0)),
                ('error_count', models.PositiveIntegerField(default=0)),
                ('success_count', models.PositiveIntegerField(default=0)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.CreateModel(
            name='ForexApiRequestLog',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('service', models.CharField(db_index=True, max_length=40)),
                ('endpoint', models.CharField(max_length=200)),
                ('success', models.BooleanField(default=True)),
                ('status_code', models.PositiveIntegerField(blank=True, null=True)),
                ('response_ms', models.PositiveIntegerField(blank=True, null=True)),
                ('error_type', models.CharField(blank=True, default='', max_length=64)),
                ('created_at', models.DateTimeField(auto_now_add=True, db_index=True)),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]
