"""Collect uploaded KYC / F&O files for admin review."""

from __future__ import annotations

from accounts.models import KycDocument, User
from kyc.models import FnoEligibilityRequest, KycProfile

from .media_urls import admin_file_url


def collect_user_kyc_documents(user: User, profile: KycProfile, request) -> list[dict]:
    documents: list[dict] = []
    seen_urls: set[str] = set()

    def add(doc_type: str, label: str, file_field, status: str = '') -> None:
        url = admin_file_url(request, file_field)
        if not url or url in seen_urls:
            return
        seen_urls.add(url)
        documents.append(
            {
                'type': doc_type,
                'label': label,
                'url': url,
                'status': status or '',
            }
        )

    if profile.selfie_image:
        add('selfie', 'Selfie', profile.selfie_image, profile.selfie_status)

    for kdoc in user.kyc_documents.all().order_by('-uploaded_at'):
        add(
            kdoc.document_type,
            kdoc.get_document_type_display(),
            kdoc.file,
            kdoc.status,
        )

    latest_pan = (
        user.kyc_requests.prefetch_related('images').order_by('-created_at').first()
    )
    if latest_pan:
        add('pan', 'PAN document', latest_pan.pan_image, latest_pan.status.lower())
        for idx, img in enumerate(latest_pan.images.all(), start=2):
            add('pan', f'PAN document {idx}', img.image, latest_pan.status.lower())

    latest_fno = (
        user.fno_requests.exclude(document='')
        .order_by('-created_at')
        .first()
    )
    if latest_fno and latest_fno.document:
        add(
            'fno',
            latest_fno.get_proof_type_display(),
            latest_fno.document,
            latest_fno.status.lower(),
        )

    return documents


def profile_document_fields(user: User, profile: KycProfile, request) -> dict:
    documents = collect_user_kyc_documents(user, profile, request)
    selfie_url = next((d['url'] for d in documents if d['type'] == 'selfie'), '')
    pan_urls = [d['url'] for d in documents if d['type'] == 'pan']
    return {
        'selfieUrl': selfie_url,
        'documents': documents,
        'panDocumentUrls': pan_urls,
        'hasDocuments': bool(documents),
    }
