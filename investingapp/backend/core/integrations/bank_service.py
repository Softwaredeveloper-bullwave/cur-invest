"""Bank validation and IFSC lookup — Razorpay public API (free, no API key)."""

from __future__ import annotations

import json
import logging
import re
from functools import lru_cache
from pathlib import Path
from urllib.parse import quote

import httpx
from django.core.cache import cache

logger = logging.getLogger('bullwave.integrations')

IFSC_REGEX = re.compile(r'^[A-Z]{4}0[A-Z0-9]{6}$')
RAZORPAY_IFSC_URL = 'https://ifsc.razorpay.com'
RAZORPAY_SEARCH_URL = f'{RAZORPAY_IFSC_URL}/search'
BANKNAMES_PATH = Path(__file__).resolve().parent.parent / 'data' / 'banknames.json'

INDIAN_STATES = [
    'ANDAMAN AND NICOBAR ISLANDS',
    'ANDHRA PRADESH',
    'ARUNACHAL PRADESH',
    'ASSAM',
    'BIHAR',
    'CHANDIGARH',
    'CHHATTISGARH',
    'DADRA AND NAGAR HAVELI AND DAMAN AND DIU',
    'DELHI',
    'GOA',
    'GUJARAT',
    'HARYANA',
    'HIMACHAL PRADESH',
    'JAMMU AND KASHMIR',
    'JHARKHAND',
    'KARNATAKA',
    'KERALA',
    'LADAKH',
    'LAKSHADWEEP',
    'MADHYA PRADESH',
    'MAHARASHTRA',
    'MANIPUR',
    'MEGHALAYA',
    'MIZORAM',
    'NAGALAND',
    'ODISHA',
    'PUDUCHERRY',
    'PUNJAB',
    'RAJASTHAN',
    'SIKKIM',
    'TAMIL NADU',
    'TELANGANA',
    'TRIPURA',
    'UTTAR PRADESH',
    'UTTARAKHAND',
    'WEST BENGAL',
]


class BankValidationError(Exception):
    pass


def _normalize(value: str) -> str:
    return re.sub(r'\s+', ' ', (value or '').strip().upper())


def _search_ifsc(
    *,
    bank_code: str = '',
    query: str = '',
    limit: int = 50,
    offset: int = 0,
) -> dict:
    params: dict[str, str | int] = {
        'limit': min(max(limit, 1), 100),
        'offset': max(offset, 0),
    }
    if bank_code:
        params['bankcode'] = bank_code.upper().strip()
    if query:
        params['q'] = query.strip()

    try:
        with httpx.Client(timeout=15) as client:
            response = client.get(RAZORPAY_SEARCH_URL, params=params)
    except httpx.HTTPError as exc:
        raise BankValidationError(f'Bank search failed: {exc}') from exc

    if response.is_error:
        raise BankValidationError('Unable to search banks right now.')

    return response.json()


def _filter_branch_rows(
    rows: list[dict],
    *,
    state: str = '',
    city: str = '',
    query: str = '',
) -> list[dict]:
    state_norm = _normalize(state)
    city_norm = _normalize(city)
    query_norm = _normalize(query)

    filtered: list[dict] = []
    for row in rows:
        row_state = _normalize(row.get('STATE', ''))
        row_city = _normalize(row.get('CITY', ''))
        row_district = _normalize(row.get('DISTRICT', ''))
        row_branch = _normalize(row.get('BRANCH', ''))

        if state_norm and row_state != state_norm:
            continue
        if city_norm and city_norm not in {row_city, row_district}:
            continue
        if query_norm and query_norm not in row_branch and query_norm not in row_city:
            continue
        filtered.append(row)
    return filtered


def _branch_payload(row: dict) -> dict:
    return {
        'ifsc': row.get('IFSC', ''),
        'branch': row.get('BRANCH', ''),
        'bank': row.get('BANK', ''),
        'bankCode': row.get('BANKCODE', ''),
        'city': row.get('CITY', ''),
        'district': row.get('DISTRICT', ''),
        'state': row.get('STATE', ''),
        'address': row.get('ADDRESS', ''),
    }


@lru_cache(maxsize=1)
def list_banks() -> list[dict]:
    try:
        raw = json.loads(BANKNAMES_PATH.read_text(encoding='utf-8'))
    except OSError as exc:
        logger.error('banknames.json missing: %s', exc)
        raise BankValidationError('Bank directory unavailable.') from exc

    return [
        {'code': code, 'name': name}
        for code, name in sorted(raw.items(), key=lambda item: item[1].lower())
    ]


def list_states() -> list[str]:
    return INDIAN_STATES.copy()


def list_cities(*, bank_code: str, state: str, query: str = '', limit: int = 50) -> list[str]:
    if not bank_code or not state:
        raise BankValidationError('Bank and state are required.')

    cache_key = f'bank-cities:{bank_code}:{state}:{query}:{limit}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    cities: dict[str, None] = {}
    offset = 0
    search_query = query.strip() or state.split()[0]
    while len(cities) < limit and offset <= 500:
        payload = _search_ifsc(bank_code=bank_code, query=search_query, limit=100, offset=offset)
        rows = _filter_branch_rows(payload.get('data', []), state=state, query=query)
        for row in rows:
            city = (row.get('CITY') or row.get('DISTRICT') or '').strip()
            if city:
                cities[city.upper()] = None
            if len(cities) >= limit:
                break
        if not payload.get('hasNext') or not payload.get('data'):
            break
        offset += 100

    result = sorted(cities.keys())
    cache.set(cache_key, result, timeout=60 * 60)
    return result


def search_branches(
    *,
    bank_code: str,
    state: str = '',
    city: str = '',
    query: str = '',
    limit: int = 50,
    offset: int = 0,
) -> dict:
    if not bank_code:
        raise BankValidationError('Bank is required.')

    search_query = query.strip() or city.strip() or state.split()[0]
    payload = _search_ifsc(
        bank_code=bank_code,
        query=search_query,
        limit=100,
        offset=offset,
    )
    rows = _filter_branch_rows(
        payload.get('data', []),
        state=state,
        city=city,
        query=query,
    )

    branches = [_branch_payload(row) for row in rows[:limit]]
    return {
        'branches': branches,
        'count': len(branches),
        'hasNext': bool(payload.get('hasNext')) and len(rows) >= limit,
    }


def validate_ifsc(ifsc: str) -> dict:
    code = (ifsc or '').upper().strip()
    if not IFSC_REGEX.match(code):
        raise BankValidationError('Invalid IFSC format.')

    cache_key = f'ifsc-lookup:{code}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(f'{RAZORPAY_IFSC_URL}/{quote(code)}')
    except httpx.HTTPError as exc:
        raise BankValidationError(f'IFSC lookup failed: {exc}') from exc

    if response.status_code == 404:
        raise BankValidationError('IFSC code not found.')
    if response.is_error:
        raise BankValidationError('Unable to validate IFSC right now.')

    data = response.json()
    result = {
        'bank': data.get('BANK', ''),
        'bankCode': data.get('BANKCODE', ''),
        'branch': data.get('BRANCH', ''),
        'city': data.get('CITY', ''),
        'district': data.get('DISTRICT', ''),
        'state': data.get('STATE', ''),
        'ifsc': data.get('IFSC', code),
        'address': data.get('ADDRESS', ''),
    }
    cache.set(cache_key, result, timeout=60 * 60 * 24)
    return result


def validate_account_number(account_number: str) -> None:
    acct = re.sub(r'\s', '', account_number or '')
    if not re.match(r'^\d{9,18}$', acct):
        raise BankValidationError('Account number must be 9–18 digits.')
