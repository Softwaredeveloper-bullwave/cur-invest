from django.db.models import Prefetch
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    EducationArticle,
    EducationCategory,
    EducationQuiz,
    EducationQuizAttempt,
    EducationQuizQuestion,
)
from .serializers import (
    EducationArticleSerializer,
    EducationCategorySerializer,
    EducationQuizSerializer,
)


class EducationCatalogView(APIView):
    """Full education tree — categories, articles, quizzes."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        categories = (
            EducationCategory.objects.filter(is_active=True)
            .prefetch_related(
                Prefetch(
                    'articles',
                    queryset=EducationArticle.objects.filter(is_active=True).order_by('sort_order'),
                ),
                Prefetch(
                    'quizzes',
                    queryset=EducationQuiz.objects.filter(is_active=True)
                    .prefetch_related(
                        Prefetch(
                            'questions',
                            queryset=EducationQuizQuestion.objects.order_by('sort_order'),
                        )
                    )
                    .order_by('sort_order'),
                ),
            )
            .order_by('sort_order')
        )
        latest = categories.order_by('-updated_at').values_list('updated_at', flat=True).first()
        return Response({
            'updatedAt': latest or timezone.now(),
            'categories': EducationCategorySerializer(categories, many=True).data,
        })


class EducationCategoryDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, slug):
        try:
            category = (
                EducationCategory.objects.filter(is_active=True, slug=slug)
                .prefetch_related(
                    Prefetch(
                        'articles',
                        queryset=EducationArticle.objects.filter(is_active=True).order_by('sort_order'),
                    ),
                    Prefetch(
                        'quizzes',
                        queryset=EducationQuiz.objects.filter(is_active=True)
                        .prefetch_related('questions')
                        .order_by('sort_order'),
                    ),
                )
                .get()
            )
        except EducationCategory.DoesNotExist:
            return Response({'detail': 'Category not found.'}, status=404)
        return Response(EducationCategorySerializer(category).data)


class EducationArticleDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, category_slug, article_slug):
        try:
            article = EducationArticle.objects.select_related('category').get(
                is_active=True,
                category__slug=category_slug,
                category__is_active=True,
                slug=article_slug,
            )
        except EducationArticle.DoesNotExist:
            return Response({'detail': 'Article not found.'}, status=404)
        return Response(EducationArticleSerializer(article).data)


class EducationQuizDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, quiz_slug):
        try:
            quiz = (
                EducationQuiz.objects.filter(is_active=True, slug=quiz_slug)
                .prefetch_related(
                    Prefetch(
                        'questions',
                        queryset=EducationQuizQuestion.objects.order_by('sort_order'),
                    )
                )
                .get()
            )
        except EducationQuiz.DoesNotExist:
            return Response({'detail': 'Quiz not found.'}, status=404)
        return Response(EducationQuizSerializer(quiz).data)


class EducationQuizSubmitView(APIView):
    """Grade quiz answers server-side and persist attempt with per-question results."""

    permission_classes = [IsAuthenticated]

    def post(self, request, quiz_slug):
        try:
            quiz = (
                EducationQuiz.objects.filter(is_active=True, slug=quiz_slug)
                .prefetch_related(
                    Prefetch(
                        'questions',
                        queryset=EducationQuizQuestion.objects.order_by('sort_order'),
                    )
                )
                .get()
            )
        except EducationQuiz.DoesNotExist:
            return Response({'detail': 'Quiz not found.'}, status=404)

        answers = request.data.get('answers') or request.data.get('Answers') or []
        if not isinstance(answers, list):
            return Response({'detail': 'answers must be a list of option indices.'}, status=400)

        questions = list(quiz.questions.all())
        if not questions:
            return Response({'detail': 'Quiz has no questions.'}, status=400)

        results = []
        score = 0
        for idx, question in enumerate(questions):
            selected = answers[idx] if idx < len(answers) else None
            if selected is not None and not isinstance(selected, int):
                try:
                    selected = int(selected)
                except (TypeError, ValueError):
                    selected = None
            is_correct = selected is not None and selected == question.correct_index
            if is_correct:
                score += 1
            results.append({
                'prompt': question.prompt,
                'options': question.options,
                'selectedIndex': selected,
                'correctIndex': question.correct_index,
                'isCorrect': is_correct,
                'explanation': question.explanation,
            })

        total = len(questions)
        percent = round((score / total) * 100) if total else 0
        attempt = EducationQuizAttempt.objects.create(
            user=request.user,
            quiz=quiz,
            score=score,
            total=total,
            answers=answers,
        )

        return Response({
            'attemptId': str(attempt.id),
            'quizSlug': quiz.slug,
            'quizTitle': quiz.title,
            'score': score,
            'total': total,
            'percent': percent,
            'results': results,
            'completedAt': attempt.completed_at,
        })


class EducationQuizAttemptsView(APIView):
    """Latest attempt per quiz for the current user."""

    permission_classes = [IsAuthenticated]

    def get(self, request, quiz_slug):
        try:
            quiz = EducationQuiz.objects.get(is_active=True, slug=quiz_slug)
        except EducationQuiz.DoesNotExist:
            return Response({'detail': 'Quiz not found.'}, status=404)

        attempt = (
            EducationQuizAttempt.objects.filter(user=request.user, quiz=quiz)
            .order_by('-completed_at')
            .first()
        )
        if attempt is None:
            return Response({'attempt': None})

        percent = round((attempt.score / attempt.total) * 100) if attempt.total else 0
        return Response({
            'attempt': {
                'attemptId': str(attempt.id),
                'score': attempt.score,
                'total': attempt.total,
                'percent': percent,
                'answers': attempt.answers,
                'completedAt': attempt.completed_at,
            },
        })
