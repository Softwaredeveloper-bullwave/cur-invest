from django.core.management.base import BaseCommand, CommandError
from django.db.utils import OperationalError

from education.models import EducationArticle, EducationCategory, EducationQuiz, EducationQuizQuestion
from education.seed_data import CATALOG
from education.seed_alt_markets import CRYPTO_CATALOG, FOREX_CATALOG

_RDS_BUSY = (
    'RDS has no free connections. Stop the API first, wait for leftover backends, then seed:\n'
    '  bash ~/cur-invest/investingapp/backend/deploy/free_rds_slots.sh\n'
    '  python manage.py seed_education\n'
    '  sudo systemctl start bullwave'
)


class Command(BaseCommand):
    help = 'Seed or refresh investment education catalog (Documents + Quizzes)'

    def handle(self, *args, **options):
        try:
            self._seed()
        except OperationalError as exc:
            raise CommandError(f'{_RDS_BUSY}\n\n({exc})') from exc

    def _seed(self):
        created_cats = 0
        for entry in [*CATALOG, *CRYPTO_CATALOG, *FOREX_CATALOG]:
            category, created = EducationCategory.objects.update_or_create(
                slug=entry['slug'],
                defaults={
                    'title': entry['title'],
                    'subtitle': entry['subtitle'],
                    'icon_name': entry['icon_name'],
                    'accent_hex': entry['accent_hex'],
                    'sort_order': entry['sort_order'],
                    'is_active': True,
                },
            )
            if created:
                created_cats += 1

            for idx, article in enumerate(entry.get('articles', [])):
                EducationArticle.objects.update_or_create(
                    category=category,
                    slug=article['slug'],
                    defaults={
                        'title': article['title'],
                        'summary': article['summary'],
                        'sections': article['sections'],
                        'read_minutes': article.get('read_minutes', 4),
                        'level': article.get('level', 'Beginner'),
                        'sort_order': idx,
                        'is_active': True,
                    },
                )

            for qidx, quiz in enumerate(entry.get('quizzes', [])):
                quiz_obj, _ = EducationQuiz.objects.update_or_create(
                    category=category,
                    slug=quiz['slug'],
                    defaults={
                        'title': quiz['title'],
                        'description': quiz['description'],
                        'sort_order': qidx,
                        'is_active': True,
                    },
                )
                quiz_obj.questions.all().delete()
                for oidx, question in enumerate(quiz.get('questions', [])):
                    EducationQuizQuestion.objects.create(
                        quiz=quiz_obj,
                        prompt=question['prompt'],
                        options=question['options'],
                        correct_index=question['correct_index'],
                        explanation=question['explanation'],
                        sort_order=oidx,
                    )

        total_articles = EducationArticle.objects.filter(is_active=True).count()
        total_quizzes = EducationQuiz.objects.filter(is_active=True).count()
        total_questions = EducationQuizQuestion.objects.count()
        self.stdout.write(
            self.style.SUCCESS(
                f'Education catalog ready — {EducationCategory.objects.count()} categories, '
                f'{total_articles} articles, {total_quizzes} quizzes, {total_questions} questions.'
            )
        )
