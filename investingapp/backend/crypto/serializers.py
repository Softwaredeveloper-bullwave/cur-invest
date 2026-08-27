from rest_framework import serializers

from .models import (
    CryptoNotificationPreference,
    CryptoPriceAlert,
    CryptoTransaction,
    CryptoWatchlistItem,
    UserMarketPreference,
)


class UserMarketPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserMarketPreference
        fields = (
            'indian_market_enabled',
            'crypto_market_enabled',
            'forex_market_enabled',
            'active_market',
            'has_completed_selection',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('created_at', 'updated_at')

    def validate(self, attrs):
        indian = attrs.get(
            'indian_market_enabled',
            getattr(self.instance, 'indian_market_enabled', True) if self.instance else True,
        )
        crypto = attrs.get(
            'crypto_market_enabled',
            getattr(self.instance, 'crypto_market_enabled', False) if self.instance else False,
        )
        forex = attrs.get(
            'forex_market_enabled',
            getattr(self.instance, 'forex_market_enabled', False) if self.instance else False,
        )
        if not indian and not crypto and not forex:
            raise serializers.ValidationError('Select at least one market.')
        active = (
            attrs.get('active_market')
            or (getattr(self.instance, 'active_market', 'indian') if self.instance else 'indian')
            or 'indian'
        )
        active = str(active).strip().lower()
        if active not in ('indian', 'crypto', 'forex'):
            raise serializers.ValidationError({'active_market': 'Must be indian, crypto, or forex.'})
        enabled = [name for name, flag in (('indian', indian), ('crypto', crypto), ('forex', forex)) if flag]
        if len(enabled) == 1:
            active = enabled[0]
        attrs['active_market'] = active
        attrs['indian_market_enabled'] = active == 'indian'
        attrs['crypto_market_enabled'] = active == 'crypto'
        attrs['forex_market_enabled'] = active == 'forex'
        return attrs


class CryptoWatchlistItemSerializer(serializers.ModelSerializer):
    asset_id = serializers.CharField(source='asset.id', read_only=True)
    symbol = serializers.CharField(source='asset.symbol', read_only=True)
    name = serializers.CharField(source='asset.name', read_only=True)
    image_url = serializers.CharField(source='asset.image_url', read_only=True)

    class Meta:
        model = CryptoWatchlistItem
        fields = ('id', 'asset_id', 'symbol', 'name', 'image_url', 'added_at')


class CryptoTransactionSerializer(serializers.ModelSerializer):
    asset_id = serializers.CharField(source='asset.id', read_only=True, allow_null=True)
    symbol = serializers.SerializerMethodField()

    class Meta:
        model = CryptoTransaction
        fields = (
            'id',
            'asset_id',
            'symbol',
            'tx_type',
            'quantity',
            'price',
            'total_value',
            'fees',
            'currency',
            'exchange',
            'external_id',
            'status',
            'is_paper',
            'notes',
            'created_at',
        )

    def get_symbol(self, obj):
        return obj.asset.symbol.upper() if obj.asset_id else ''


class CryptoPriceAlertSerializer(serializers.ModelSerializer):
    asset_id = serializers.CharField(source='asset.id', read_only=True)

    class Meta:
        model = CryptoPriceAlert
        fields = (
            'id',
            'asset_id',
            'condition',
            'target_value',
            'is_active',
            'created_at',
        )


class CryptoNotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = CryptoNotificationPreference
        fields = (
            'price_alerts',
            'news_alerts',
            'volatility_alerts',
            'percent_move_threshold',
            'updated_at',
        )
        read_only_fields = ('updated_at',)
