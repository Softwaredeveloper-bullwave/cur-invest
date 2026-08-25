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
        if not indian and not crypto:
            raise serializers.ValidationError('Select at least one market.')
        # Exclusive markets: keep one only
        if indian and crypto:
            active = (attrs.get('active_market') or 'indian').strip().lower()
            if active == 'crypto':
                attrs['indian_market_enabled'] = False
                attrs['crypto_market_enabled'] = True
                attrs['active_market'] = 'crypto'
            else:
                attrs['indian_market_enabled'] = True
                attrs['crypto_market_enabled'] = False
                attrs['active_market'] = 'indian'
            return attrs
        active = attrs.get('active_market')
        if active and active not in ('indian', 'crypto'):
            raise serializers.ValidationError({'active_market': 'Must be indian or crypto.'})
        if crypto and not indian:
            attrs['active_market'] = 'crypto'
        elif indian and not crypto:
            attrs['active_market'] = 'indian'
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
