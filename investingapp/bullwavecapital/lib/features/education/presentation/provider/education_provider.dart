import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/investment_doc_model.dart';

class EducationProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<InvestmentDocCategory> _categories = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  DateTime? _updatedAt;
  final Map<String, QuizAttemptResult> _latestAttempts = {};

  List<InvestmentDocCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  DateTime? get updatedAt => _updatedAt;

  QuizAttemptResult? latestAttemptFor(String quizSlug) => _latestAttempts[quizSlug];

  Future<void> ensureLoaded({bool force = false}) async {
    if (_hasLoaded && _categories.isNotEmpty && !force) return;
    await loadCatalog(force: force);
  }

  Future<void> loadCatalog({bool force = false}) async {
    if (_isLoading) return;
    if (_categories.isNotEmpty && !force) {
      _hasLoaded = true;
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final catalog = await _api.getEducationCatalog();
      _categories = catalog.categories;
      _updatedAt = catalog.updatedAt;
      _error = null;
      _hasLoaded = true;
    } on ApiException catch (e) {
      _error = e.message;
      if (_categories.isEmpty) _hasLoaded = true;
    } catch (_) {
      _error = 'Could not load documents. Is Django running?';
      if (_categories.isEmpty) _hasLoaded = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadCatalog(force: true);

  InvestmentDocCategory? categoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  InvestmentDocArticle? articleById(String categoryId, String articleId) {
    final cat = categoryById(categoryId);
    if (cat == null) return null;
    try {
      return cat.articles.firstWhere((a) => a.id == articleId);
    } catch (_) {
      return null;
    }
  }

  InvestmentDocQuiz? quizById(String quizId) {
    for (final cat in _categories) {
      for (final quiz in cat.quizzes) {
        if (quiz.id == quizId) return quiz;
      }
    }
    return null;
  }

  Future<InvestmentDocCategory?> fetchCategory(String slug, {bool force = false}) async {
    await ensureLoaded(force: force);
    final cached = categoryById(slug);
    if (cached != null && !force) return cached;

    try {
      final category = await _api.getEducationCategory(slug);
      _mergeCategory(category);
      notifyListeners();
      return category;
    } catch (_) {
      return cached;
    }
  }

  Future<InvestmentDocArticle?> fetchArticle(
    String categorySlug,
    String articleSlug, {
    bool force = false,
  }) async {
    await ensureLoaded(force: force);
    final cached = articleById(categorySlug, articleSlug);
    if (cached != null && !force) return cached;

    try {
      final article = await _api.getEducationArticle(categorySlug, articleSlug);
      _mergeArticle(article);
      notifyListeners();
      return article;
    } catch (_) {
      return cached;
    }
  }

  Future<InvestmentDocQuiz?> fetchQuiz(String quizSlug, {bool force = false}) async {
    await ensureLoaded();
    final cached = quizById(quizSlug);
    if (cached != null && cached.questions.isNotEmpty && !force) return cached;

    try {
      final quiz = await _api.getEducationQuiz(quizSlug);
      _mergeQuiz(quiz);
      notifyListeners();
      return quiz;
    } catch (_) {
      return cached;
    }
  }

  Future<QuizAttemptResult?> submitQuiz(String quizSlug, List<int?> answers) async {
    try {
      final result = await _api.submitEducationQuiz(quizSlug, answers);
      _latestAttempts[quizSlug] = result;
      notifyListeners();
      return result;
    } catch (_) {
      return null;
    }
  }

  void _mergeCategory(InvestmentDocCategory category) {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      _categories[idx] = category;
    } else {
      _categories = [..._categories, category]..sort((a, b) => a.title.compareTo(b.title));
    }
  }

  void _mergeArticle(InvestmentDocArticle article) {
    final catIdx = _categories.indexWhere((c) => c.id == article.categoryId);
    if (catIdx < 0) return;
    final cat = _categories[catIdx];
    final articles = [...cat.articles];
    final aIdx = articles.indexWhere((a) => a.id == article.id);
    if (aIdx >= 0) {
      articles[aIdx] = article;
    } else {
      articles.add(article);
    }
    _categories[catIdx] = InvestmentDocCategory(
      id: cat.id,
      title: cat.title,
      subtitle: cat.subtitle,
      iconName: cat.iconName,
      accentHex: cat.accentHex,
      articles: articles,
      quizzes: cat.quizzes,
    );
  }

  void _mergeQuiz(InvestmentDocQuiz quiz) {
    for (var i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final idx = cat.quizzes.indexWhere((q) => q.id == quiz.id);
      if (idx >= 0) {
        final quizzes = [...cat.quizzes];
        quizzes[idx] = quiz;
        _categories[i] = InvestmentDocCategory(
          id: cat.id,
          title: cat.title,
          subtitle: cat.subtitle,
          iconName: cat.iconName,
          accentHex: cat.accentHex,
          articles: cat.articles,
          quizzes: quizzes,
        );
        return;
      }
    }
  }
}
