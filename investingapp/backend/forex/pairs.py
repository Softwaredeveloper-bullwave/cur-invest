"""Canonical FX pairs used by every provider — ids are lowercase with no slash."""

from __future__ import annotations

# id, base, quote, display name, category
FOREX_PAIRS: tuple[tuple[str, str, str, str, str], ...] = (
    ('eurusd', 'EUR', 'USD', 'Euro / US Dollar', 'Majors'),
    ('gbpusd', 'GBP', 'USD', 'British Pound / US Dollar', 'Majors'),
    ('usdjpy', 'USD', 'JPY', 'US Dollar / Japanese Yen', 'Majors'),
    ('usdchf', 'USD', 'CHF', 'US Dollar / Swiss Franc', 'Majors'),
    ('audusd', 'AUD', 'USD', 'Australian Dollar / US Dollar', 'Majors'),
    ('usdcad', 'USD', 'CAD', 'US Dollar / Canadian Dollar', 'Majors'),
    ('nzdusd', 'NZD', 'USD', 'New Zealand Dollar / US Dollar', 'Majors'),
    ('eurgbp', 'EUR', 'GBP', 'Euro / British Pound', 'Crosses'),
    ('eurjpy', 'EUR', 'JPY', 'Euro / Japanese Yen', 'Crosses'),
    ('gbpjpy', 'GBP', 'JPY', 'British Pound / Japanese Yen', 'Crosses'),
    ('eurchf', 'EUR', 'CHF', 'Euro / Swiss Franc', 'Crosses'),
    ('audjpy', 'AUD', 'JPY', 'Australian Dollar / Japanese Yen', 'Crosses'),
    ('usdinr', 'USD', 'INR', 'US Dollar / Indian Rupee', 'Exotics'),
    ('eurinr', 'EUR', 'INR', 'Euro / Indian Rupee', 'Exotics'),
    ('gbpinr', 'GBP', 'INR', 'British Pound / Indian Rupee', 'Exotics'),
    ('usdcny', 'USD', 'CNY', 'US Dollar / Chinese Yuan', 'Exotics'),
    ('usdtry', 'USD', 'TRY', 'US Dollar / Turkish Lira', 'Exotics'),
    ('usdzar', 'USD', 'ZAR', 'US Dollar / South African Rand', 'Exotics'),
)

PAIR_BY_ID = {row[0]: row for row in FOREX_PAIRS}


def normalize_pair_id(value: str) -> str:
    raw = (value or '').strip().lower().replace('/', '').replace('-', '').replace('_', '')
    if raw in PAIR_BY_ID:
        return raw
    for pid, base, quote, *_ in FOREX_PAIRS:
        if raw == f'{base}{quote}'.lower() or raw == f'{base}/{quote}'.lower():
            return pid
    return raw


def pair_symbol(pair_id: str) -> str:
    row = PAIR_BY_ID.get(normalize_pair_id(pair_id))
    if not row:
        return (pair_id or '').upper()
    return f'{row[1]}/{row[2]}'
