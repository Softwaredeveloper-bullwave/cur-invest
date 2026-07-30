from __future__ import annotations

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.integrations.bank_service import (
    BankValidationError,
    list_banks,
    list_cities,
    list_states,
    search_branches,
    validate_ifsc,
)


class BankListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = (request.query_params.get('q') or '').strip().lower()
        banks = list_banks()
        if query:
            banks = [
                bank
                for bank in banks
                if query in bank['name'].lower() or query in bank['code'].lower()
            ]
        return Response({'banks': banks[:200], 'count': len(banks)})


class BankStateListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = (request.query_params.get('q') or '').strip().upper()
        states = list_states()
        if query:
            states = [state for state in states if query in state]
        return Response({'states': states, 'count': len(states)})


class BankCityListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        bank_code = (request.query_params.get('bankCode') or '').strip()
        state = (request.query_params.get('state') or '').strip()
        query = (request.query_params.get('q') or '').strip()
        try:
            cities = list_cities(bank_code=bank_code, state=state, query=query)
        except BankValidationError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response({'cities': cities, 'count': len(cities)})


class BankBranchSearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        bank_code = (request.query_params.get('bankCode') or '').strip()
        state = (request.query_params.get('state') or '').strip()
        city = (request.query_params.get('city') or '').strip()
        query = (request.query_params.get('q') or '').strip()
        offset = int(request.query_params.get('offset') or 0)
        limit = min(int(request.query_params.get('limit') or 50), 100)
        try:
            payload = search_branches(
                bank_code=bank_code,
                state=state,
                city=city,
                query=query,
                limit=limit,
                offset=offset,
            )
        except BankValidationError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)


class IfscLookupView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, ifsc: str):
        try:
            data = validate_ifsc(ifsc)
        except BankValidationError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(data)
