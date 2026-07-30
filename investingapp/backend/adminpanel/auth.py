from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework_simplejwt.authentication import JWTAuthentication

from accounts.models import User

DEV_ADMIN_PHONE = '9000000099'


def get_dev_admin_user():
    user, _created = User.objects.get_or_create(
        phone=DEV_ADMIN_PHONE,
        defaults={
            'name': 'Dev Admin',
            'is_staff': True,
            'is_superuser': True,
            'is_active': True,
        },
    )
    updates = []
    if not user.is_staff:
        user.is_staff = True
        updates.append('is_staff')
    if not user.is_superuser:
        user.is_superuser = True
        updates.append('is_superuser')
    if not user.is_active:
        user.is_active = True
        updates.append('is_active')
    if updates:
        user.save(update_fields=updates)
    return user


class AdminPanelDevAuthentication(BaseAuthentication):
    """Local development only: auto-authenticate as a staff user when DEBUG is on."""

    def authenticate(self, request):
        if not settings.ADMIN_PANEL_DEV_NO_AUTH:
            return None
        return (get_dev_admin_user(), None)


def admin_panel_authentication_classes():
    return [AdminPanelDevAuthentication, JWTAuthentication]
