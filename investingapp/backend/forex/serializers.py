from rest_framework import serializers

from .models import ForexNotificationPreference, ForexTransaction, ForexWatchlistItem


class ForexWatchlistItemSerializer(serializers.ModelSerializer):
    pair_id = serializers.CharField(source='pair.id', read_only=True)
    asset_id = serializers.CharField(source='pair.id', read_only=True)
    symbol = serializers.CharField(source='pair.symbol', read_only=True)
    name = serializers.CharField(source='pair.name', read_only=True)

    class Meta:
        model = ForexWatchlistItem
        fields = ('id', 'pair_id', 'asset_id', 'symbol', 'name', 'added_at')


class ForexTransactionSerializer(serializers.ModelSerializer):
    pair_id = serializers.CharField(source='pair.id', read_only=True, allow_null=True)
    symbol = serializers.SerializerMethodField()

    class Meta:
        model = ForexTransaction
        fields = (
            'id',
            'pair_id',
            'symbol',
            'tx_type',
            'quantity',
            'price',
            'total_value',
            'fees',
            'currency',
            'exchange',
            'status',
            'is_paper',
            'notes',
            'created_at',
        )

    def get_symbol(self, obj):
        return obj.pair.symbol if obj.pair_id else ''


class ForexNotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = ForexNotificationPreference
        fields = ('price_alerts', 'news_alerts', 'updated_at')
        read_only_fields = ('updated_at',)
