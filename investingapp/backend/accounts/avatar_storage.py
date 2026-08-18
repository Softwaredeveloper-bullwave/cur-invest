"""Avatar upload helpers — ensure media dirs exist and normalize images for storage."""

from __future__ import annotations

import logging
from io import BytesIO

from django.conf import settings
from django.core.files.base import ContentFile
from PIL import Image, UnidentifiedImageError

logger = logging.getLogger('bullwave.accounts')

_MAX_AVATAR_BYTES = 5 * 1024 * 1024
_MAX_AVATAR_SIDE = 1024


def ensure_media_dirs() -> None:
    media_root = settings.MEDIA_ROOT
    media_root.mkdir(parents=True, exist_ok=True)
    (media_root / 'avatars').mkdir(parents=True, exist_ok=True)


def normalize_avatar_upload(uploaded_file) -> ContentFile:
    """Decode, resize, and re-encode as JPEG so mobile gallery/camera uploads always save."""
    uploaded_file.seek(0)
    try:
        with Image.open(uploaded_file) as img:
            img = img.convert('RGB')
            img.thumbnail((_MAX_AVATAR_SIDE, _MAX_AVATAR_SIDE), Image.Resampling.LANCZOS)
            buf = BytesIO()
            img.save(buf, format='JPEG', quality=85, optimize=True)
    except UnidentifiedImageError as exc:
        raise ValueError('Use a valid JPEG or PNG photo.') from exc

    data = buf.getvalue()
    if not data:
        raise ValueError('Photo file is empty.')
    if len(data) > _MAX_AVATAR_BYTES:
        raise ValueError('Image must be under 5 MB.')
    return ContentFile(data, name='avatar.jpg')
