"""Mask sensitive KYC fields for API responses."""


def mask_pan(pan: str) -> str:
    pan = (pan or '').upper().strip()
    if len(pan) != 10:
        return '****'
    return f'{pan[:2]}*****{pan[-2:]}'


def mask_account_number(account: str) -> str:
    acct = (account or '').strip()
    if len(acct) <= 4:
        return acct
    return f'****{acct[-4:]}'


def mask_aadhaar(aadhaar: str) -> str:
    value = (aadhaar or '').strip()
    if len(value) == 4 and value.isdigit():
        return f'XXXX XXXX {value}'
    if len(value) != 12 or not value.isdigit():
        return '****'
    return f'XXXX XXXX {value[-4:]}'


def mask_upi_vpa(vpa: str) -> str:
    value = (vpa or '').strip().lower()
    if '@' not in value:
        return '****'
    local, handle = value.split('@', 1)
    if len(local) <= 2:
        masked_local = '*' * len(local)
    else:
        masked_local = f'{local[:2]}***'
    return f'{masked_local}@{handle}'
