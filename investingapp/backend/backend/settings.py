from pathlib import Path

from decouple import Config, RepositoryEnv
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

_env_file = BASE_DIR / '.env'
if _env_file.is_file():
    config = Config(RepositoryEnv(str(_env_file)))
else:
    from decouple import config  # noqa: F401 — falls back to cwd / environment variables


def _clean_env(value: str, *, strip_trailing_slash: bool = False) -> str:
    """Strip accidental inline # comments and whitespace from .env values."""
    cleaned = (value or '').split('#', 1)[0].strip()
    if strip_trailing_slash:
        cleaned = cleaned.rstrip('/')
    return cleaned


def _ascii_env(value: str) -> str:
    """API keys must be ASCII — rejects copy-paste corruption (e.g. Cyrillic lookalikes)."""
    cleaned = _clean_env(value)
    if not cleaned:
        return ''
    ascii_only = ''.join(ch for ch in cleaned if ord(ch) < 128)
    return ascii_only.strip()

SECRET_KEY = config('SECRET_KEY', default='django-insecure-dev-key-change-in-production')
DEBUG = config('DEBUG', default=True, cast=bool)
# Open admin-panel APIs without JWT while DEBUG=True (disable before go-live).
ADMIN_PANEL_DEV_NO_AUTH = DEBUG and config('ADMIN_PANEL_DEV_NO_AUTH', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1,10.0.2.2').split(',')
if DEBUG:
    ALLOWED_HOSTS = ['*']

EKO_LOG_LEVEL = _clean_env(config('EKO_LOG_LEVEL', default='INFO')).upper() or 'INFO'
EKO_API_LOG_FILE = _clean_env(config('EKO_API_LOG_FILE', default=''))
if DEBUG and not EKO_API_LOG_FILE:
    EKO_API_LOG_FILE = 'logs/eko_kyc.log'

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s',
            'datefmt': '%Y-%m-%d %H:%M:%S',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'error_database': {
            'class': 'core.logging_handler.DatabaseErrorHandler',
            'level': 'ERROR',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django.request': {
            'handlers': ['console', 'error_database'],
            'level': 'ERROR',
            'propagate': False,
        },
        'bullwave': {
            'handlers': ['error_database'],
            'level': 'ERROR',
            'propagate': False,
        },
        'bullwave.requests': {
            'handlers': ['console'],
            'level': 'INFO',
        },
        'bullwave.ai': {
            'handlers': ['console'],
            'level': 'INFO',
        },
        'bullwave.kyc': {
            'handlers': ['console', 'error_database'],
            'level': EKO_LOG_LEVEL,
            'propagate': False,
        },
    },
}

if EKO_API_LOG_FILE:
    _eko_log_path = Path(EKO_API_LOG_FILE)
    if not _eko_log_path.is_absolute():
        _eko_log_path = BASE_DIR / _eko_log_path
    _eko_log_path.parent.mkdir(parents=True, exist_ok=True)
    LOGGING['handlers']['eko_file'] = {
        'class': 'logging.FileHandler',
        'filename': str(_eko_log_path),
        'formatter': 'verbose',
    }
    LOGGING['loggers']['bullwave.kyc']['handlers'].append('eko_file')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'accounts.apps.AccountsConfig',
    'kyc',
    'payments',
    'finance',
    'adminpanel.apps.AdminPanelConfig',
    'stocks.apps.StocksConfig',
    'engagement',
    'education',
    'ai',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'core.middleware.RequestLogMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

_db_ssl_mode = _clean_env(config('DB_SSL_MODE', default=''))
_db_ssl_root_cert = _clean_env(config('DB_SSL_ROOT_CERT', default=''))
if _db_ssl_root_cert and not Path(_db_ssl_root_cert).is_absolute():
    _db_ssl_root_cert = str((BASE_DIR / _db_ssl_root_cert).resolve())

_db_options: dict = {}
if _db_ssl_mode:
    _db_options['sslmode'] = _db_ssl_mode
if _db_ssl_root_cert:
    _db_options['sslrootcert'] = _db_ssl_root_cert

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='bullwave_db'),
        'USER': config('DB_USER', default='postgres'),
        'PASSWORD': config('DB_PASSWORD', default='postgres'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
        **({'OPTIONS': _db_options} if _db_options else {}),
    }
}

AUTH_USER_MODEL = 'accounts.User'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DATETIME_FORMAT': '%Y-%m-%dT%H:%M:%S.%fZ',
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
}

CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = config(
    'CORS_ALLOWED_ORIGINS',
    default='http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173',
    cast=lambda v: [origin.strip() for origin in v.split(',') if origin.strip()],
)

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'bullwave-cache',
    }
}

OTP_EXPIRY_MINUTES = config('OTP_EXPIRY_MINUTES', default=5, cast=int)
SMS_OTP_ENABLED = config('SMS_OTP_ENABLED', default=True, cast=bool)
# When SMS is off or provider falls back to console, return devOtp in API (for AWS/demo).
SMS_EXPOSE_DEV_OTP = config('SMS_EXPOSE_DEV_OTP', default=not SMS_OTP_ENABLED, cast=bool)

# AI assistant — default: Ollama (local, free). See ai/ollama_client.py
AI_PROVIDER = config('AI_PROVIDER', default='ollama')
AI_SKIP_STARTUP_PROBE = config('AI_SKIP_STARTUP_PROBE', default=False, cast=bool)
OPENAI_API_KEY = _ascii_env(config('OPENAI_API_KEY', default=''))
OPENAI_ORG_ID = _ascii_env(config('OPENAI_ORG_ID', default=''))
OPENAI_PROJECT_ID = _ascii_env(config('OPENAI_PROJECT_ID', default=''))
OPENAI_MODEL = config('OPENAI_MODEL', default='gpt-4o-mini')
# OpenAI voice — TTS + Whisper STT (same API key as chat)
AI_VOICE_PROVIDER = config('AI_VOICE_PROVIDER', default='auto')  # auto | openai | elevenlabs
OPENAI_TTS_MODEL = config('OPENAI_TTS_MODEL', default='tts-1')  # tts-1 | tts-1-hd
OPENAI_TTS_VOICE = config('OPENAI_TTS_VOICE', default='shimmer')  # shimmer/coral = warm female voice
OPENAI_TTS_SPEED = config('OPENAI_TTS_SPEED', default=0.93, cast=float)
OPENAI_TTS_MAX_CHARS = config('OPENAI_TTS_MAX_CHARS', default=4096, cast=int)
OPENAI_STT_MODEL = config('OPENAI_STT_MODEL', default='whisper-1')
OPENAI_STT_ENABLED = config('OPENAI_STT_ENABLED', default=True, cast=bool)
OPENAI_STT_MAX_BYTES = config('OPENAI_STT_MAX_BYTES', default=25 * 1024 * 1024, cast=int)
OPENAI_VOICE_TIMEOUT = config('OPENAI_VOICE_TIMEOUT', default=60, cast=int)
GEMINI_API_KEY = config('GEMINI_API_KEY', default='')
GEMINI_MODEL = config('GEMINI_MODEL', default='gemini-2.0-flash')
GROQ_API_KEY = config('GROQ_API_KEY', default='')
GROQ_MODEL = config('GROQ_MODEL', default='llama-3.1-8b-instant')
OLLAMA_BASE_URL = config('OLLAMA_BASE_URL', default='http://127.0.0.1:11434')
OLLAMA_MODEL = config('OLLAMA_MODEL', default='llama3.2:1b')
OLLAMA_KEEP_ALIVE = config('OLLAMA_KEEP_ALIVE', default='30m')
OLLAMA_NUM_CTX = config('OLLAMA_NUM_CTX', default=2048, cast=int)
AI_TEMPERATURE = config('AI_TEMPERATURE', default=0.4, cast=float)
AI_MAX_TOKENS = config('AI_MAX_TOKENS', default=500, cast=int)
AI_REQUEST_TIMEOUT = config('AI_REQUEST_TIMEOUT', default=90, cast=int)

# ElevenLabs — AI voice (text-to-speech). Get key: https://elevenlabs.io/app/settings/api-keys
ELEVENLABS_API_KEY = config('ELEVENLABS_API_KEY', default='')
ELEVENLABS_VOICE_ID = config('ELEVENLABS_VOICE_ID', default='')
ELEVENLABS_MODEL_ID = config('ELEVENLABS_MODEL_ID', default='eleven_turbo_v2_5')
ELEVENLABS_TIMEOUT = config('ELEVENLABS_TIMEOUT', default=45, cast=int)

# Real-time market data — Kotak Neo (primary) / Finnhub / Yahoo
# Kotak v2 SDK calls the dashboard token "consumer_key"; we accept either env name.
KOTAK_NEO_ACCESS_TOKEN = config('KOTAK_NEO_ACCESS_TOKEN', default='') or config(
    'KOTAK_NEO_CONSUMER_KEY', default=''
)
KOTAK_NEO_BASE_URL = config('KOTAK_NEO_BASE_URL', default='https://mis.kotaksecurities.com')
KOTAK_NEO_QUOTE_CACHE_SECONDS = config('KOTAK_NEO_QUOTE_CACHE_SECONDS', default=15, cast=int)
KOTAK_NEO_UNIVERSE_CACHE_SECONDS = config('KOTAK_NEO_UNIVERSE_CACHE_SECONDS', default=15, cast=int)
KOTAK_NEO_BATCH_SIZE = config('KOTAK_NEO_BATCH_SIZE', default=50, cast=int)
MARKET_DATA_PROVIDER = config('MARKET_DATA_PROVIDER', default='auto')  # auto | kotak_neo | finnhub | yahoo
ALPHA_VANTAGE_API_KEY = config('ALPHA_VANTAGE_API_KEY', default='')
ALPHA_VANTAGE_REQUEST_DELAY_SECONDS = config('ALPHA_VANTAGE_REQUEST_DELAY_SECONDS', default=12, cast=int)
ALPHA_VANTAGE_QUOTE_CACHE_SECONDS = config('ALPHA_VANTAGE_QUOTE_CACHE_SECONDS', default=120, cast=int)
ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH = config('ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH', default=5, cast=int)
FINNHUB_API_KEY = config('FINNHUB_API_KEY', default='')
MARKET_QUOTE_CACHE_SECONDS = config('MARKET_QUOTE_CACHE_SECONDS', default=30, cast=int)
MARKET_UNIVERSE_CACHE_SECONDS = config('MARKET_UNIVERSE_CACHE_SECONDS', default=60, cast=int)
NEWS_CACHE_MINUTES = config('NEWS_CACHE_MINUTES', default=15, cast=int)

# TradingView — widget embed works without a key; set these when using Charting Library + UDF
TRADINGVIEW_API_KEY = config('TRADINGVIEW_API_KEY', default='')
TRADINGVIEW_CHARTING_LIBRARY_URL = config('TRADINGVIEW_CHARTING_LIBRARY_URL', default='')
TRADINGVIEW_UDF_BASE_URL = config('TRADINGVIEW_UDF_BASE_URL', default='')
TRADINGVIEW_DEFAULT_EXCHANGE = config('TRADINGVIEW_DEFAULT_EXCHANGE', default='NSE')

# SMS OTP — console (dev), 2factor, infobip, msg91, twilio
_sms_provider_raw = _clean_env(config('SMS_PROVIDER', default='console')).lower()
if _sms_provider_raw in {'twofactor', 'two-factor', 'two_factor'}:
    _sms_provider_raw = '2factor'
TWOFACTOR_API_KEY = _ascii_env(config('TWOFACTOR_API_KEY', default=''))
TWOFACTOR_OTP_TEMPLATE = _clean_env(config('TWOFACTOR_OTP_TEMPLATE', default='BullwaveClub_OTP'))
TWOFACTOR_SENDER_ID = _clean_env(config('TWOFACTOR_SENDER_ID', default='BWCLUB'))
# autogen = 2Factor generates OTP | manual = backend generates OTP and sends via template
TWOFACTOR_OTP_MODE = _clean_env(config('TWOFACTOR_OTP_MODE', default='autogen')).lower() or 'autogen'
INFOBIP_API_KEY = _ascii_env(config('INFOBIP_API_KEY', default=''))
INFOBIP_BASE_URL = _clean_env(config('INFOBIP_BASE_URL', default='')).rstrip('/')
INFOBIP_SENDER = _clean_env(config('INFOBIP_SENDER', default=''))
INFOBIP_OTP_MESSAGE = config(
    'INFOBIP_OTP_MESSAGE',
    default='Your BullWave Capital OTP is {otp}. Valid for {minutes} minutes.',
)
INFOBIP_DLT_ENTITY_ID = _clean_env(config('INFOBIP_DLT_ENTITY_ID', default=''))
INFOBIP_DLT_TEMPLATE_ID = _clean_env(config('INFOBIP_DLT_TEMPLATE_ID', default=''))
INFOBIP_DLT_TELEMARKETER_ID = _clean_env(config('INFOBIP_DLT_TELEMARKETER_ID', default=''))
MSG91_AUTH_KEY = _ascii_env(config('MSG91_AUTH_KEY', default=''))
MSG91_TEMPLATE_ID = _clean_env(config('MSG91_TEMPLATE_ID', default=''))
TWILIO_ACCOUNT_SID = _ascii_env(config('TWILIO_ACCOUNT_SID', default=''))
TWILIO_AUTH_TOKEN = _ascii_env(config('TWILIO_AUTH_TOKEN', default=''))
TWILIO_FROM_NUMBER = _clean_env(config('TWILIO_FROM_NUMBER', default=''))
TWILIO_SERVICE_SID = _ascii_env(config('TWILIO_SERVICE_SID', default=''))
TWILIO_VERIFY_CHANNEL = _clean_env(config('TWILIO_VERIFY_CHANNEL', default='sms')) or 'sms'
# verify = Twilio Verify API (TWILIO_SERVICE_SID) | messages = DB OTP via TWILIO_FROM_NUMBER
TWILIO_OTP_MODE = _clean_env(config('TWILIO_OTP_MODE', default='verify')).lower() or 'verify'

if TWILIO_FROM_NUMBER and not TWILIO_FROM_NUMBER.startswith('+'):
    TWILIO_FROM_NUMBER = f'+{TWILIO_FROM_NUMBER.lstrip("+")}'

_infobip_ready = bool(INFOBIP_API_KEY and INFOBIP_BASE_URL and INFOBIP_SENDER)
_twilio_ready = bool(
    TWILIO_ACCOUNT_SID
    and TWILIO_AUTH_TOKEN
    and (TWILIO_SERVICE_SID or TWILIO_FROM_NUMBER)
)
_msg91_ready = bool(MSG91_AUTH_KEY and MSG91_TEMPLATE_ID)
_twofactor_ready = bool(TWOFACTOR_API_KEY)

if _sms_provider_raw == 'console':
    if _twofactor_ready:
        SMS_PROVIDER = '2factor'
    elif _infobip_ready:
        SMS_PROVIDER = 'infobip'
    elif _twilio_ready:
        SMS_PROVIDER = 'twilio'
    elif _msg91_ready:
        SMS_PROVIDER = 'msg91'
    else:
        SMS_PROVIDER = 'console'
else:
    SMS_PROVIDER = _sms_provider_raw

# Payments — Razorpay (https://dashboard.razorpay.com)
RAZORPAY_KEY_ID = config('RAZORPAY_KEY_ID', default='')
RAZORPAY_KEY_SECRET = config('RAZORPAY_KEY_SECRET', default='')
RAZORPAY_WEBHOOK_SECRET = config('RAZORPAY_WEBHOOK_SECRET', default='')

# Verification & Payments — Cashfree (credentials from env only)
CASHFREE_CLIENT_ID = config('CASHFREE_CLIENT_ID', default='')
CASHFREE_CLIENT_SECRET = config('CASHFREE_CLIENT_SECRET', default='')
CASHFREE_ENVIRONMENT = config('CASHFREE_ENVIRONMENT', default='')
CASHFREE_ENV = config('CASHFREE_ENV', default='sandbox')
CASHFREE_API_VERSION = config('CASHFREE_API_VERSION', default='2022-10-26')
CASHFREE_PAYMENT_API_VERSION = config('CASHFREE_PAYMENT_API_VERSION', default='2023-08-01')
CASHFREE_PAYMENTS_BASE_URL = config('CASHFREE_PAYMENTS_BASE_URL', default='')
CASHFREE_PAYOUTS_BASE_URL = config('CASHFREE_PAYOUTS_BASE_URL', default='')
CASHFREE_PAYMENT_WEBHOOK_SECRET = config('CASHFREE_PAYMENT_WEBHOOK_SECRET', default='')
CASHFREE_PAYOUT_WEBHOOK_SECRET = config('CASHFREE_PAYOUT_WEBHOOK_SECRET', default='')
CASHFREE_WEBHOOK_SECRET = config('CASHFREE_WEBHOOK_SECRET', default='')
SECURE_ID_BASE_URL = config('SECURE_ID_BASE_URL', default='')
SECURE_ID_API_KEY = config('SECURE_ID_API_KEY', default='')
SECURE_ID_API_SECRET = config('SECURE_ID_API_SECRET', default='')

# KYC provider — legacy default when per-step KYC_*_PROVIDER vars are unset
KYC_PROVIDER = _clean_env(config('KYC_PROVIDER', default='cashfree')).lower() or 'cashfree'
# Per-step overrides (fall back to KYC_PROVIDER when blank)
KYC_PAN_PROVIDER = _clean_env(config('KYC_PAN_PROVIDER', default='')).lower() or ''
KYC_BANK_PROVIDER = _clean_env(config('KYC_BANK_PROVIDER', default='')).lower() or ''
KYC_UPI_PROVIDER = _clean_env(config('KYC_UPI_PROVIDER', default='')).lower() or ''
KYC_AADHAAR_PROVIDER = _clean_env(config('KYC_AADHAAR_PROVIDER', default='')).lower() or ''
# provider: call Cashfree/Eko immediately; manual: staff review within 24 hours.
KYC_BANK_REVIEW_MODE = _clean_env(config('KYC_BANK_REVIEW_MODE', default='provider')).lower()
if KYC_BANK_REVIEW_MODE not in {'provider', 'manual'}:
    KYC_BANK_REVIEW_MODE = 'provider'

# Verification — Eko Platform Services (https://developers.eko.in) — paste keys in .env
EKO_DEVELOPER_KEY = _ascii_env(config('EKO_DEVELOPER_KEY', default=''))
EKO_ACCESS_KEY = _ascii_env(config('EKO_ACCESS_KEY', default=''))
EKO_INITIATOR_ID = _clean_env(config('EKO_INITIATOR_ID', default=''))
EKO_USER_CODE = _clean_env(config('EKO_USER_CODE', default=''))
EKO_ENVIRONMENT = _clean_env(config('EKO_ENVIRONMENT', default='uat'))
EKO_BASE_URL = _clean_env(config('EKO_BASE_URL', default=''), strip_trailing_slash=True)
# Optional override when UPI validate-vpa lives on a different Eko host/port than KYC tools.
EKO_UPI_BASE_URL = _clean_env(config('EKO_UPI_BASE_URL', default=''), strip_trailing_slash=True)
EKO_ALLOW_SANDBOX_BYPASS = config('EKO_ALLOW_SANDBOX_BYPASS', default=False, cast=bool)
# Prefer Eko Penny-less bank verification; fall back to penny-drop when unavailable.
EKO_PENNYLESS_ENABLED = config('EKO_PENNYLESS_ENABLED', default=True, cast=bool)
# Partner slug from Eko Connect (docs example: touras).
EKO_ORG_SLUG = _clean_env(config('EKO_ORG_SLUG', default=''))
# Optional full override; leave blank to derive /v3/tools/kyc/{slug}/bank-acc-verify-penniless
EKO_PENNYLESS_PATH = _clean_env(config('EKO_PENNYLESS_PATH', default=''))
# Eko PAN/bank/UPI calls can be slow in production — allow up to 90s read time.
EKO_HTTP_TIMEOUT_SECONDS = config('EKO_HTTP_TIMEOUT_SECONDS', default=90, cast=int)
# Optional public HTTPS override after DigiLocker consent. Leave blank to use
# BACKEND_PUBLIC_URL/api/v1/digilocker/callback/{state}/ (never the marketing site).
EKO_DIGILOCKER_REDIRECT_URL = _clean_env(
    config('EKO_DIGILOCKER_REDIRECT_URL', default=''),
    strip_trailing_slash=True,
)
# Flutter/web app URL for redirect after DigiLocker callback (e.g. http://localhost:58076).
APP_WEB_URL = _clean_env(config('APP_WEB_URL', default=''), strip_trailing_slash=True)
# A URL-safe Fernet key used only for Aadhaar numbers held during an active
# OTP transaction. Generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
AADHAAR_ENCRYPTION_KEY = _ascii_env(config('AADHAAR_ENCRYPTION_KEY', default=''))

# Compliance
KYC_AUTO_APPROVE = config('KYC_AUTO_APPROVE', default=False, cast=bool)
# Opt-in dev bypasses only — must stay False for real PAN/bank/UPI verification.
# These do NOT default from KYC_AUTO_APPROVE (which only affects document upload approval).
CASHFREE_DEV_BYPASS = config('CASHFREE_DEV_BYPASS', default=False, cast=bool)
EKO_UPI_SOFT_VERIFY = config('EKO_UPI_SOFT_VERIFY', default=False, cast=bool)
EKO_BANK_SOFT_VERIFY = config('EKO_BANK_SOFT_VERIFY', default=False, cast=bool)
# Testing only — skip PAN/Aadhaar name match during bank verify (Eko account-exists check only).
# Must stay False in production.
KYC_BANK_SKIP_IDENTITY_MATCH = config('KYC_BANK_SKIP_IDENTITY_MATCH', default=False, cast=bool)
# UPI verification step in KYC — disabled for BullWave MVP (bank verify via Eko only).
KYC_UPI_REQUIRED = config('KYC_UPI_REQUIRED', default=False, cast=bool)
# Manual UPI ID review after bank verify (no Eko UPI API). User submits UPI + selfie together.
KYC_UPI_MANUAL = config('KYC_UPI_MANUAL', default=True, cast=bool)
# Admin must click final approve after UPI + selfie review (replaces auto name-match gate).
KYC_MANUAL_FINAL_APPROVAL = config('KYC_MANUAL_FINAL_APPROVAL', default=True, cast=bool)
# Dev/testing — relax KYC endpoint rate limits (defaults to DEBUG). Keep False in production.
KYC_RELAX_RATE_LIMITS = config('KYC_RELAX_RATE_LIMITS', default=DEBUG, cast=bool)
REFERRAL_REWARD_AMOUNT = config('REFERRAL_REWARD_AMOUNT', default=500, cast=int)
APP_SHARE_URL = config('APP_SHARE_URL', default='https://bullwave.in')
# Public URL for email action links (approve/reject). Use your deployed API URL or ngrok in dev.
BACKEND_PUBLIC_URL = _clean_env(config('BACKEND_PUBLIC_URL', default='http://127.0.0.1:8000'), strip_trailing_slash=True)
# HTTPS tunnel for local DigiLocker callbacks (localtunnel / ngrok). Example: https://abc123.loca.lt
LOCAL_DEV_TUNNEL_URL = _clean_env(config('LOCAL_DEV_TUNNEL_URL', default=''), strip_trailing_slash=True)

# Manual KYC admin email — set SMTP credentials in .env for production.
# If left empty, backend will default to: bullwaveteam5@gmail.com
ADMIN_KYC_EMAIL = _clean_env(config('ADMIN_KYC_EMAIL', default=''))
# F&O admin inbox — defaults to ADMIN_KYC_EMAIL when empty
ADMIN_FNO_EMAIL = _clean_env(config('ADMIN_FNO_EMAIL', default=''))
# Phone for auto-created Django reviewer used by email Approve/Reject links (optional)
KYC_EMAIL_REVIEWER_PHONE = _clean_env(config('KYC_EMAIL_REVIEWER_PHONE', default=''))
EMAIL_BACKEND = config('EMAIL_BACKEND', default='django.core.mail.backends.console.EmailBackend')
EMAIL_HOST = _clean_env(config('EMAIL_HOST', default=''))
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_HOST_USER = _clean_env(config('EMAIL_HOST_USER', default=''))
_raw_email_password = _clean_env(config('EMAIL_HOST_PASSWORD', default=''))
# Gmail app passwords are 16 chars; copy-paste often adds spaces or dashes.
EMAIL_HOST_PASSWORD = _raw_email_password.replace(' ', '').replace('-', '')
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
DEFAULT_FROM_EMAIL = _clean_env(config('DEFAULT_FROM_EMAIL', default='noreply@bullwave.app'))

# Production email via API key (recommended over Gmail SMTP)
# Brevo: https://app.brevo.com/settings/keys/api
# SendGrid: https://app.sendgrid.com/settings/api_keys
EMAIL_PROVIDER = _clean_env(config('EMAIL_PROVIDER', default='smtp')).lower() or 'smtp'
BREVO_API_KEY = _ascii_env(config('BREVO_API_KEY', default=''))
BREVO_FROM_EMAIL = _clean_env(config('BREVO_FROM_EMAIL', default=''))
BREVO_FROM_NAME = _clean_env(config('BREVO_FROM_NAME', default='BullWave Capital')) or 'BullWave Capital'
SENDGRID_API_KEY = _ascii_env(config('SENDGRID_API_KEY', default=''))
SENDGRID_FROM_EMAIL = _clean_env(config('SENDGRID_FROM_EMAIL', default=''))

FNO_MIN_PORTFOLIO_VALUE = config('FNO_MIN_PORTFOLIO_VALUE', default=50000, cast=int)
KITE_API_KEY = config('KITE_API_KEY', default='')
KITE_API_SECRET = config('KITE_API_SECRET', default='')
DHAN_CLIENT_ID = config('DHAN_CLIENT_ID', default='')
DHAN_ACCESS_TOKEN = config('DHAN_ACCESS_TOKEN', default='')
