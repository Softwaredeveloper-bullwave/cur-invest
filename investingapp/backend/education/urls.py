from django.urls import path

from .views import (
    EducationArticleDetailView,
    EducationCatalogView,
    EducationCategoryDetailView,
    EducationQuizAttemptsView,
    EducationQuizDetailView,
    EducationQuizSubmitView,
)

urlpatterns = [
    path('education/catalog/', EducationCatalogView.as_view(), name='education-catalog'),
    path('education/categories/<slug:slug>/', EducationCategoryDetailView.as_view(), name='education-category'),
    path(
        'education/categories/<slug:category_slug>/articles/<slug:article_slug>/',
        EducationArticleDetailView.as_view(),
        name='education-article',
    ),
    path('education/quizzes/<slug:quiz_slug>/', EducationQuizDetailView.as_view(), name='education-quiz'),
    path('education/quizzes/<slug:quiz_slug>/submit/', EducationQuizSubmitView.as_view(), name='education-quiz-submit'),
    path('education/quizzes/<slug:quiz_slug>/attempts/', EducationQuizAttemptsView.as_view(), name='education-quiz-attempts'),
]
