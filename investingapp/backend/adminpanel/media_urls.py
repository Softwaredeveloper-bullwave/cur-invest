"""Absolute media URLs for admin-panel document links."""

from django.conf import settings


def admin_file_url(request, file_field) -> str:
    if not file_field:
        return ''
    try:
        rel = file_field.url
    except (ValueError, AttributeError):
        return ''
    if not rel:
        return ''
    if rel.startswith(('http://', 'https://')):
        return rel
    base = (getattr(settings, 'BACKEND_PUBLIC_URL', '') or '').strip().rstrip('/')
    if not base:
        if request is not None:
            return request.build_absolute_uri(rel)
        return rel
    if not rel.startswith('/'):
        rel = f'/{rel}'
    return f'{base}{rel}'
