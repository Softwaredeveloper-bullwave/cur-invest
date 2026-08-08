"""SMS OTP delivery — 2Factor, Infobip, MSG91, Twilio Messages, Twilio Verify, or console (dev)."""

import json
import logging
import re
import socket

import httpx
from django.conf import settings

logger = logging.getLogger('bullwave.integrations')


class SMSError(Exception):
    pass


def _twofactor_ready() -> bool:
    api_key = (getattr(settings, 'TWOFACTOR_API_KEY', '') or '').strip()
    return bool(api_key)


def _twofactor_template() -> str:
    return (
        getattr(settings, 'TWOFACTOR_OTP_TEMPLATE', 'BullwaveClub_OTP') or 'BullwaveClub_OTP'
    ).strip()


def _twofactor_otp_mode() -> str:
    mode = (getattr(settings, 'TWOFACTOR_OTP_MODE', 'autogen') or 'autogen').lower().strip()
    return 'manual' if mode == 'manual' else 'autogen'


def uses_2factor() -> bool:
    return _explicit_sms_provider() == '2factor'


def uses_2factor_live() -> bool:
    return uses_2factor() and _twofactor_ready()


def uses_2factor_autogen() -> bool:
    return uses_2factor_live() and _twofactor_otp_mode() == 'autogen'


def uses_2factor_manual() -> bool:
    return uses_2factor_live() and _twofactor_otp_mode() == 'manual'


def _twilio_credentials_ready() -> bool:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    return bool(account_sid and auth_token)


def _twilio_verify_ready() -> bool:
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    return _twilio_credentials_ready() and bool(service_sid)


def _twilio_message_ready() -> bool:
    from_number = (getattr(settings, 'TWILIO_FROM_NUMBER', '') or '').strip()
    return _twilio_credentials_ready() and bool(from_number)


def _msg91_ready() -> bool:
    auth_key = (getattr(settings, 'MSG91_AUTH_KEY', '') or '').strip()
    template_id = (getattr(settings, 'MSG91_TEMPLATE_ID', '') or '').strip()
    return bool(auth_key and template_id)


def _infobip_ready() -> bool:
    api_key = (getattr(settings, 'INFOBIP_API_KEY', '') or '').strip()
    base_url = (getattr(settings, 'INFOBIP_BASE_URL', '') or '').strip()
    sender = (getattr(settings, 'INFOBIP_SENDER', '') or '').strip()
    return bool(api_key and base_url and sender)


def _explicit_sms_provider() -> str:
    """Configured provider from Django settings (before resolve fallbacks)."""
    provider = (getattr(settings, 'SMS_PROVIDER', 'console') or 'console').lower().strip()
    if provider in {'twofactor', 'two-factor', 'two_factor'}:
        return '2factor'
    return provider


def resolve_sms_provider() -> str:
    """Effective SMS provider for sending."""
    provider = _explicit_sms_provider()
    if provider == '2factor':
        return '2factor'
    if provider == 'infobip' and not _infobip_ready():
        return 'console'
    if provider == 'twilio' and not (_twilio_verify_ready() or _twilio_message_ready()):
        return 'console'
    if provider == 'msg91' and not _msg91_ready():
        return 'console'
    return provider


def _twilio_otp_mode() -> str:
    """verify | messages — messages forces DB-stored OTP via Twilio Messages API."""
    mode = (getattr(settings, 'TWILIO_OTP_MODE', 'verify') or 'verify').lower().strip()
    return 'messages' if mode == 'messages' else 'verify'


def uses_twilio_verify() -> bool:
    return (
        resolve_sms_provider() == 'twilio'
        and _twilio_verify_ready()
        and _twilio_otp_mode() == 'verify'
    )


def twilio_message_ready() -> bool:
    return _twilio_message_ready()


def twilio_verify_delivery_blocked(exc: Exception) -> bool:
    text = str(exc or '')
    return any(
        token in text
        for token in ('60238', '21408', 'blocked by Twilio', 'Geo Permission')
    )


def friendly_twilio_error(exc: Exception) -> str:
    text = str(exc or '')
    if '60238' in text or 'blocked by Twilio' in text:
        return (
            'Twilio blocked OTP to this number. In Twilio Console open '
            'Messaging → Settings → Geo permissions and enable India (+91). '
            'If your account upgrade is under review, wait or contact Twilio Support. '
            'Alternative: buy a Twilio SMS number, set TWILIO_FROM_NUMBER in .env, '
            'and set TWILIO_OTP_MODE=messages.'
        )
    if '21408' in text or 'Geo Permission' in text:
        return (
            'Twilio geo permissions block SMS to India. Enable India (+91) under '
            'Twilio Console → Messaging → Geo permissions.'
        )
    return text


def is_live_sms() -> bool:
    return resolve_sms_provider() != 'console'


def _infobip_dlt_settings() -> tuple[str, str, str]:
    entity_id = (getattr(settings, 'INFOBIP_DLT_ENTITY_ID', '') or '').strip()
    template_id = (getattr(settings, 'INFOBIP_DLT_TEMPLATE_ID', '') or '').strip()
    telemarketer_id = (getattr(settings, 'INFOBIP_DLT_TELEMARKETER_ID', '') or '').strip()
    return entity_id, template_id, telemarketer_id


def _india_dlt_ready() -> bool:
    entity_id, template_id, _ = _infobip_dlt_settings()
    return bool(entity_id and template_id)


def friendly_2factor_error(exc: Exception) -> str:
    text = str(exc or '')
    lowered = text.lower()
    if 'invalid api key' in lowered or 'authentication' in lowered:
        return '2Factor API key is invalid. Check TWOFACTOR_API_KEY in backend/.env.'
    if 'insufficient' in lowered or 'balance' in lowered:
        return '2Factor SMS OTP balance is insufficient. Recharge in the 2Factor dashboard.'
    if 'template' in lowered:
        return (
            f'{text} Confirm TWOFACTOR_OTP_TEMPLATE matches your approved template name '
            '(e.g. BullwaveClub_OTP).'
        )
    return text


def validate_2factor_config() -> list[str]:
    provider = _explicit_sms_provider()
    if provider != '2factor':
        return []

    problems = []
    if not (getattr(settings, 'TWOFACTOR_API_KEY', '') or '').strip():
        problems.append('TWOFACTOR_API_KEY is missing in backend/.env')
    if not (getattr(settings, 'TWOFACTOR_OTP_TEMPLATE', '') or '').strip():
        problems.append('TWOFACTOR_OTP_TEMPLATE is missing (approved OTP template name from 2Factor)')
    if not getattr(settings, 'SMS_OTP_ENABLED', True):
        problems.append('SMS_OTP_ENABLED=False — OTP will not be sent via 2Factor (dev/console mode)')
    return problems


def friendly_infobip_error(exc: Exception) -> str:
    text = str(exc or '')
    lowered = text.lower()
    if 'rejected' in lowered or 'undeliverable' in lowered:
        return (
            f'{text} Check INFOBIP_SENDER and INFOBIP_BASE_URL in backend/.env, '
            'and confirm the sender is approved in your Infobip account.'
        )
    if 'unauthorized' in lowered or '401' in lowered:
        return 'Infobip API key is invalid. Regenerate INFOBIP_API_KEY in the Infobip portal.'
    return text


def validate_infobip_config() -> list[str]:
    """Return list of configuration problems (empty = OK)."""
    provider = (getattr(settings, 'SMS_PROVIDER', 'console') or 'console').lower().strip()
    if provider != 'infobip':
        return []

    problems = []
    api_key = (getattr(settings, 'INFOBIP_API_KEY', '') or '').strip()
    base_url = (getattr(settings, 'INFOBIP_BASE_URL', '') or '').strip()
    sender = (getattr(settings, 'INFOBIP_SENDER', '') or '').strip()

    if not api_key:
        problems.append('INFOBIP_API_KEY is missing in backend/.env')
    if not base_url:
        problems.append(
            'INFOBIP_BASE_URL is missing (copy from Infobip portal, e.g. https://xxxxx.api.infobip.com)'
        )
    elif not base_url.startswith('http'):
        problems.append('INFOBIP_BASE_URL must start with https://')
    if not sender:
        problems.append('INFOBIP_SENDER is missing (approved sender ID from Infobip portal)')

    return problems


def validate_twilio_config() -> list[str]:
    """Return list of configuration problems (empty = OK)."""
    provider = (getattr(settings, 'SMS_PROVIDER', 'console') or 'console').lower().strip()
    if provider != 'twilio':
        return []

    problems = []
    sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    from_number = (getattr(settings, 'TWILIO_FROM_NUMBER', '') or '').strip()

    if not sid:
        problems.append('TWILIO_ACCOUNT_SID is missing in backend/.env')
    elif not sid.startswith('AC'):
        problems.append('TWILIO_ACCOUNT_SID should start with AC')

    if not token:
        problems.append('TWILIO_AUTH_TOKEN is missing in backend/.env')

    if not service_sid and not from_number:
        problems.append(
            'Set TWILIO_SERVICE_SID (Verify, recommended) or TWILIO_FROM_NUMBER (Messages) in backend/.env'
        )
    if service_sid and not service_sid.startswith('VA'):
        problems.append('TWILIO_SERVICE_SID should start with VA (Twilio Verify Service SID)')

    return problems


def sms_config_status() -> dict:
    provider = resolve_sms_provider()
    explicit = _explicit_sms_provider()
    twilio_verify = uses_twilio_verify()
    mode = 'sms' if provider != 'console' and not (explicit == '2factor' and not _twofactor_ready()) else 'console'
    if explicit == '2factor' and _twofactor_ready():
        mode = 'sms'
    twilio_problems = validate_twilio_config()
    infobip_problems = validate_infobip_config()
    twofactor_problems = validate_2factor_config()
    problems = twilio_problems + infobip_problems + twofactor_problems
    ready = mode == 'sms' and not problems

    hints = []
    if explicit == 'infobip' and infobip_problems:
        hints.extend(infobip_problems)
    elif explicit == '2factor' and twofactor_problems:
        hints.extend(twofactor_problems)
    elif explicit == 'twilio' and twilio_problems:
        hints.extend(twilio_problems)
    elif mode == 'console':
        hints.append('OTP is NOT sent to the phone — add 2Factor, Infobip, or Twilio keys to backend/.env.')
        hints.append(
            '2Factor: SMS_PROVIDER=2factor, TWOFACTOR_API_KEY, TWOFACTOR_OTP_TEMPLATE=BullwaveClub_OTP.'
        )
        hints.append(
            'Infobip: SMS_PROVIDER=infobip, INFOBIP_API_KEY, INFOBIP_BASE_URL, INFOBIP_SENDER.'
        )

    return {
        'explicit_provider': explicit,
        'provider': (
            'twilio_verify'
            if twilio_verify
            else ('2factor_autogen' if uses_2factor_autogen() else provider)
        ),
        'mode': mode,
        'ready': ready,
        'twilio_verify': twilio_verify,
        'twofactor_configured': _twofactor_ready(),
        'twofactor_autogen': uses_2factor_autogen(),
        'infobip_configured': _infobip_ready(),
        'infobip_dlt_configured': _india_dlt_ready(),
        'msg91_configured': _msg91_ready(),
        'twilio_configured': _twilio_verify_ready() or _twilio_message_ready(),
        'twilio_problems': twilio_problems,
        'infobip_problems': infobip_problems,
        'twofactor_problems': twofactor_problems,
        'hints': hints,
        'env_file': str(getattr(settings, 'BASE_DIR', '')) + '/.env',
    }


def local_lan_ip() -> str:
    """Best-effort LAN IP for physical-device testing hints."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(('8.8.8.8', 80))
            return sock.getsockname()[0]
    except OSError:
        return ''


def _normalize_phone_2factor(phone: str) -> str:
    """2Factor expects 91XXXXXXXXXX (no + prefix)."""
    digits = re.sub(r'\D', '', phone or '')
    if len(digits) == 10:
        return f'91{digits}'
    if len(digits) == 12 and digits.startswith('91'):
        return digits
    if len(digits) == 11 and digits.startswith('0'):
        return f'91{digits[1:]}'
    return digits


def _twofactor_base_url() -> str:
    api_key = (getattr(settings, 'TWOFACTOR_API_KEY', '') or '').strip()
    if not api_key:
        raise SMSError('TWOFACTOR_API_KEY is required when SMS_PROVIDER=2factor')
    return f'https://2factor.in/API/V1/{api_key}'


def _parse_2factor_json(response: httpx.Response) -> dict:
    if response.is_error:
        detail = response.text[:300]
        raise SMSError(f'2Factor HTTP error ({response.status_code}): {detail}')
    try:
        data = response.json()
    except json.JSONDecodeError as exc:
        raise SMSError(f'2Factor returned invalid JSON: {response.text[:200]}') from exc
    if not isinstance(data, dict):
        raise SMSError('2Factor returned an unexpected response.')
    status = (data.get('Status') or data.get('status') or '').strip()
    if status.lower() != 'success':
        details = data.get('Details') or data.get('details') or data.get('Message') or status
        raise SMSError(f'2Factor error: {details}')
    return data


def send_2factor_autogen_otp(phone: str) -> str:
    """Trigger AUTOGEN OTP via 2Factor.in — returns session_id (Details field)."""
    phone_2f = _normalize_phone_2factor(phone)
    if len(phone_2f) != 12 or not phone_2f.startswith('91'):
        raise SMSError('Enter a valid 10-digit Indian mobile number for 2Factor OTP.')

    template = _twofactor_template()
    url = f'{_twofactor_base_url()}/SMS/{phone_2f}/AUTOGEN/{template}'
    try:
        with httpx.Client(timeout=20) as client:
            response = client.get(url)
    except httpx.HTTPError as exc:
        raise SMSError(f'2Factor connection failed: {exc}') from exc

    data = _parse_2factor_json(response)
    session_id = (data.get('Details') or data.get('details') or '').strip()
    if not session_id:
        raise SMSError('2Factor did not return a session id.')
    logger.info('2Factor AUTOGEN OTP sent to +%s session=%s…', phone_2f, session_id[:8])
    return session_id


def send_2factor_manual_otp(phone: str, otp: str) -> str:
    """Send backend-generated OTP through 2Factor template — returns session_id."""
    phone_2f = _normalize_phone_2factor(phone)
    if len(phone_2f) != 12 or not phone_2f.startswith('91'):
        raise SMSError('Enter a valid 10-digit Indian mobile number for 2Factor OTP.')
    if len(otp) != 6 or not otp.isdigit():
        raise SMSError('OTP must be a 6-digit code for 2Factor manual mode.')

    template = _twofactor_template()
    url = f'{_twofactor_base_url()}/SMS/{phone_2f}/{otp}/{template}'
    try:
        with httpx.Client(timeout=20) as client:
            response = client.get(url)
    except httpx.HTTPError as exc:
        raise SMSError(f'2Factor connection failed: {exc}') from exc

    data = _parse_2factor_json(response)
    session_id = (data.get('Details') or data.get('details') or '').strip()
    if not session_id:
        raise SMSError('2Factor did not return a session id.')
    logger.info('2Factor manual OTP sent to +%s session=%s…', phone_2f, session_id[:8])
    return session_id


def check_otp_2factor(session_id: str, otp: str) -> bool:
    session_id = (session_id or '').strip()
    otp = re.sub(r'\D', '', otp or '')
    if not session_id or len(otp) != 6:
        return False

    url = f'{_twofactor_base_url()}/SMS/VERIFY/{session_id}/{otp}'
    try:
        with httpx.Client(timeout=20) as client:
            response = client.get(url)
    except httpx.HTTPError as exc:
        raise SMSError(f'2Factor verify connection failed: {exc}') from exc

    try:
        data = response.json()
    except json.JSONDecodeError as exc:
        raise SMSError(f'2Factor verify returned invalid JSON: {response.text[:200]}') from exc

    status = (data.get('Status') or data.get('status') or '').strip().lower()
    details = (data.get('Details') or data.get('details') or '').strip().lower()
    if status == 'success' and ('matched' in details or details == 'otp matched'):
        return True
    if status == 'success' and not details:
        return True
    return False


def _normalize_phone_e164(phone: str) -> str:
    digits = re.sub(r'\D', '', phone or '')
    if len(digits) == 10:
        return f'+91{digits}'
    if len(digits) == 12 and digits.startswith('91'):
        return f'+{digits}'
    if phone and str(phone).strip().startswith('+'):
        return re.sub(r'\s', '', str(phone).strip())
    return f'+{digits}' if digits else ''


def send_notification_sms(phone: str, message: str) -> None:
    """Generic transactional SMS (KYC approved, etc.). Falls back to console in dev."""
    explicit = _explicit_sms_provider()
    if explicit == '2factor':
        logger.info('[BullWave SMS] 2Factor is OTP-only — skipping transactional SMS to %s', phone)
        return

    provider = resolve_sms_provider()
    body = (message or '').strip()
    if not phone or not body:
        return
    if provider == 'infobip':
        _send_infobip_message(phone, body)
    elif provider == 'twilio' and not uses_twilio_verify():
        _send_twilio_message(phone, body)
    elif provider == 'console':
        msg = f'[BullWave SMS] Phone: {phone} | {body}'
        logger.info(msg)
        if settings.DEBUG:
            import sys

            print(msg, flush=True)
            sys.stderr.write(msg + '\n')


def send_otp_sms(phone: str, otp: str) -> None:
    explicit = _explicit_sms_provider()
    if explicit == '2factor':
        if uses_2factor_manual():
            send_2factor_manual_otp(phone, otp)
        else:
            send_2factor_autogen_otp(phone)
        return

    provider = resolve_sms_provider()
    if provider == 'infobip':
        _send_infobip(phone, otp)
    elif provider == 'msg91':
        _send_msg91(phone, otp)
    elif provider == 'twilio':
        if uses_twilio_verify():
            _send_twilio_verify(phone)
        else:
            _send_twilio(phone, otp)
    else:
        _send_console(phone, otp)


def check_otp_twilio_verify(phone: str, otp: str) -> bool:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    channel = (getattr(settings, 'TWILIO_VERIFY_CHANNEL', 'sms') or 'sms').strip()

    url = f'https://verify.twilio.com/v2/Services/{service_sid}/VerificationCheck'
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                url,
                data={'To': _normalize_phone_e164(phone), 'Code': otp, 'Channel': channel},
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'Twilio Verify connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'Twilio Verify error ({response.status_code}): {response.text[:200]}')

    data = response.json()
    return (data.get('status') or '').lower() == 'approved'


def _infobip_base_url() -> str:
    base = (getattr(settings, 'INFOBIP_BASE_URL', '') or '').strip().rstrip('/')
    if not base:
        raise SMSError('INFOBIP_BASE_URL is required when SMS_PROVIDER=infobip')
    for suffix in ('/sms/2/text/advanced', '/sms/2/text', '/sms'):
        if base.endswith(suffix):
            base = base[: -len(suffix)].rstrip('/')
    return base


def _infobip_headers() -> dict:
    api_key = (getattr(settings, 'INFOBIP_API_KEY', '') or '').strip()
    if not api_key:
        raise SMSError('INFOBIP_API_KEY is required when SMS_PROVIDER=infobip')
    return {
        'Authorization': f'App {api_key}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
    }


def _infobip_otp_body(otp: str) -> str:
    template = (
        getattr(settings, 'INFOBIP_OTP_MESSAGE', '')
        or 'Your BullWave Capital OTP is {otp}. Valid for {minutes} minutes.'
    ).strip()
    try:
        return template.format(otp=otp, minutes=settings.OTP_EXPIRY_MINUTES)
    except (KeyError, ValueError) as exc:
        raise SMSError(
            'INFOBIP_OTP_MESSAGE is invalid — use only {otp} and {minutes} placeholders.'
        ) from exc


def _infobip_message_payload(phone: str, text: str) -> dict:
    sender = (getattr(settings, 'INFOBIP_SENDER', '') or '').strip()
    if not sender:
        raise SMSError('INFOBIP_SENDER is required when SMS_PROVIDER=infobip')

    to = _normalize_phone_e164(phone).lstrip('+')
    message = {
        'destinations': [{'to': to}],
        'from': sender,
        'text': text,
    }

    entity_id, template_id, telemarketer_id = _infobip_dlt_settings()
    if entity_id and template_id:
        india_dlt = {
            'principalEntityId': entity_id,
            'contentTemplateId': template_id,
        }
        if telemarketer_id:
            india_dlt['telemarketerId'] = telemarketer_id
        message['regional'] = {'indiaDlt': india_dlt}

    return {'messages': [message]}


def _parse_infobip_send_response(data: dict) -> dict:
    messages = data.get('messages') or []
    if not messages:
        return {}
    entry = messages[0] or {}
    status = entry.get('status') or {}
    group_id = status.get('groupId')
    group_name = status.get('groupName') or status.get('name') or ''
    description = status.get('description') or group_name or 'Unknown status'
    # 1=PENDING accepted, 3=DELIVERED; 2=UNDELIVERABLE, 4=EXPIRED, 5=REJECTED
    if group_id in (2, 4, 5):
        raise SMSError(f'Infobip rejected SMS: {description}')
    return {
        'messageId': entry.get('messageId'),
        'status': description,
        'groupId': group_id,
        'groupName': group_name,
    }


def _send_infobip_message(phone: str, body: str) -> dict:
    url = f'{_infobip_base_url()}/sms/2/text/advanced'
    payload = _infobip_message_payload(phone, body)
    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(url, json=payload, headers=_infobip_headers())
    except httpx.HTTPError as exc:
        raise SMSError(f'Infobip connection failed: {exc}') from exc

    if response.is_error:
        detail = response.text[:400]
        if response.status_code == 401:
            raise SMSError('Infobip API key rejected (401). Check INFOBIP_API_KEY.')
        raise SMSError(f'Infobip error ({response.status_code}): {detail}')

    try:
        data = response.json()
    except json.JSONDecodeError as exc:
        raise SMSError(f'Infobip returned invalid JSON: {response.text[:200]}') from exc

    meta = _parse_infobip_send_response(data)
    to = _normalize_phone_e164(phone).lstrip('+')
    logger.info(
        'Infobip SMS accepted for +%s messageId=%s status=%s',
        to,
        meta.get('messageId', '?'),
        meta.get('status', '?'),
    )
    return meta


def _send_infobip(phone: str, otp: str) -> None:
    _send_infobip_message(phone, _infobip_otp_body(otp))


def _send_console(phone: str, otp: str) -> None:
    msg = f'[BullWave OTP] Phone: {phone} | OTP: {otp}'
    logger.info(msg)
    if settings.DEBUG:
        import sys

        print(msg, flush=True)
        sys.stderr.write(msg + '\n')


def _send_msg91(phone: str, otp: str) -> None:
    auth_key = (getattr(settings, 'MSG91_AUTH_KEY', '') or '').strip()
    template_id = (getattr(settings, 'MSG91_TEMPLATE_ID', '') or '').strip()
    if not auth_key or not template_id:
        raise SMSError('MSG91_AUTH_KEY and MSG91_TEMPLATE_ID are required when SMS_PROVIDER=msg91')

    payload = {
        'template_id': template_id,
        'short_url': '0',
        'recipients': [{'mobiles': f'91{phone}', 'otp': otp}],
    }
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                'https://control.msg91.com/api/v5/flow/',
                json=payload,
                headers={'authkey': auth_key, 'Content-Type': 'application/json'},
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'MSG91 connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'MSG91 error ({response.status_code}): {response.text[:200]}')

    logger.info('MSG91 OTP sent to +91%s', phone)


def _send_twilio_verify(phone: str) -> None:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    channel = (getattr(settings, 'TWILIO_VERIFY_CHANNEL', 'sms') or 'sms').strip()
    to = _normalize_phone_e164(phone)

    url = f'https://verify.twilio.com/v2/Services/{service_sid}/Verifications'
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                url,
                data={'To': to, 'Channel': channel},
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'Twilio Verify connection failed: {exc}') from exc

    if response.is_error:
        code = ''
        try:
            code = str(response.json().get('code') or '')
        except json.JSONDecodeError:
            pass
        detail = response.text[:200]
        if code:
            detail = f'code {code}: {detail}'
        raise SMSError(f'Twilio Verify error ({response.status_code}): {detail}')

    logger.info('Twilio Verify OTP sent to %s', to)


def _send_twilio_message(phone: str, body: str) -> None:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    from_number = (getattr(settings, 'TWILIO_FROM_NUMBER', '') or '').strip()
    if not all([account_sid, auth_token, from_number]):
        raise SMSError(
            'TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER required for SMS notifications'
        )

    to = _normalize_phone_e164(phone)
    url = f'https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json'
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                url,
                data={'To': to, 'From': from_number, 'Body': body},
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'Twilio connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'Twilio error ({response.status_code}): {response.text[:200]}')

    logger.info('Twilio SMS sent to %s', to)


def _send_twilio(phone: str, otp: str) -> None:
    body = f'Your BullWave Capital OTP is {otp}. Valid for {settings.OTP_EXPIRY_MINUTES} minutes.'
    _send_twilio_message(phone, body)
