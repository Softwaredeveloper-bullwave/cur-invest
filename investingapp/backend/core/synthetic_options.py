"""Synthetic CE/PE books from a live spot — used by crypto and forex F&O."""

from __future__ import annotations

import math
import uuid
from datetime import date, timedelta
from decimal import Decimal


def friday_expiries(count: int = 4) -> list[date]:
    today = date.today()
    expiries: list[date] = []
    d = today
    while len(expiries) < count and (d - today).days <= 60:
        if d.weekday() == 4 and d >= today:
            expiries.append(d)
        d += timedelta(days=1)
    if not expiries:
        days_ahead = (4 - today.weekday()) % 7 or 7
        expiries.append(today + timedelta(days=days_ahead))
    return expiries[:count]


def strike_step(spot: float) -> float:
    if spot >= 20000:
        return 500
    if spot >= 5000:
        return 100
    if spot >= 1000:
        return 25
    if spot >= 200:
        return 5
    if spot >= 50:
        return 1
    if spot >= 10:
        return 0.25
    if spot >= 2:
        return 0.05
    if spot >= 0.5:
        return 0.005
    return 0.0005


def build_synthetic_option_chain(
    *,
    symbol: str,
    name: str,
    spot: float,
    asset_class: str,
    currency: str = 'USD',
    unit: str = '',
    source: str = 'live',
    expiry: date | None = None,
    vol_factor: float = 0.04,
    num_strikes: int = 21,
    trade_underlying: str = '',
) -> dict:
    expiries = friday_expiries(4)
    selected = expiry or expiries[0]
    if selected not in expiries:
        expiries = sorted({*expiries, selected})
    step = strike_step(spot)
    atm = round(spot / step) * step
    half = num_strikes // 2
    days = max((selected - date.today()).days, 1)
    contracts = []
    decimals = 6 if spot < 10 else 4 if spot < 200 else 2
    for i in range(num_strikes):
        strike = atm + (i - half) * step
        if strike <= 0:
            continue
        moneyness = abs(spot - strike) / max(spot, 1e-9)
        base_oi = int(180000 * math.exp(-moneyness * 5))
        for opt_type in ('CE', 'PE'):
            intrinsic = max(0.0, spot - strike) if opt_type == 'CE' else max(0.0, strike - spot)
            time_val = spot * vol_factor * math.sqrt(days / 365) * math.exp(-moneyness * 4)
            ltp = max(round(intrinsic + time_val, decimals), 10 ** (-decimals))
            change = round(ltp * 0.02 * (1 if opt_type == 'CE' else -1), decimals)
            contracts.append(
                {
                    'id': str(uuid.uuid4()),
                    'symbol': symbol,
                    'underlying_id': trade_underlying or symbol,
                    'strike': Decimal(str(round(strike, decimals))),
                    'type': opt_type,
                    'ltp': Decimal(str(ltp)),
                    'change': Decimal(str(change)),
                    'oi': base_oi + (20000 if abs(strike - atm) < step / 2 else 0),
                    'volume': int(base_oi * 0.12),
                    'expiry': selected.isoformat(),
                }
            )
    return {
        'symbol': symbol,
        'name': name,
        'unit': unit,
        'currency': currency,
        'underlying_value': round(spot, decimals),
        'expiry_dates': [e.isoformat() for e in expiries],
        'selected_expiry': selected.isoformat(),
        'contracts': contracts,
        'source': source,
        'asset_class': asset_class,
    }
