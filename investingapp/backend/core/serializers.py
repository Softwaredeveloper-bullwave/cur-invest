from rest_framework import serializers

from .utils import camelize, decamelize


class CamelCaseSerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if isinstance(data, dict):
            data = decamelize(data)
        return super().to_internal_value(data)

    def to_representation(self, instance):
        return camelize(super().to_representation(instance))


class CamelCaseModelSerializer(serializers.ModelSerializer):
    def to_internal_value(self, data):
        if isinstance(data, dict):
            data = decamelize(data)
        return super().to_internal_value(data)

    def to_representation(self, instance):
        return camelize(super().to_representation(instance))
