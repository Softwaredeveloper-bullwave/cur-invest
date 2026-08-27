import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../../models/investment_doc_model.dart';
import '../provider/education_provider.dart';

class DocumentCategoryScreen extends StatefulWidget {
  final String categoryId;

  const DocumentCategoryScreen({super.key, required this.categoryId});

  @override
  State<DocumentCategoryScreen> createState() => _DocumentCategoryScreenState();
}

class _DocumentCategoryScreenState extends State<DocumentCategoryScreen> {
  InvestmentDocCategory? _category;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final education = context.read<EducationProvider>();
    final category = await education.fetchCategory(
      widget.categoryId,
      force: force,
    );
    if (!mounted) return;
    setState(() {
      _category = category;
      _loadError = category == null
          ? (education.error ?? 'Category not found')
          : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_loading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Documents'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final category = _category;
    if (category == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Documents'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 48, color: p.textMuted),
                const SizedBox(height: 12),
                Text(
                  _loadError ?? 'Category not found',
                  textAlign: TextAlign.center,
                  style: ThemeAType.body(color: p.textGrey),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _load(force: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isQuizCategory = category.id == 'quizzes';
    final items = isQuizCategory
        ? category.quizzes.length
        : category.articles.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: category.title),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(category.subtitle, style: ThemeAType.body(color: p.textGrey)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: p.primaryPillDecoration(),
              child: Text(
                isQuizCategory
                    ? '${category.quizzes.length} quiz${category.quizzes.length == 1 ? '' : 'zes'} available'
                    : '${category.articles.length} investing note${category.articles.length == 1 ? '' : 's'}',
                style: ThemeAType.label(size: 11, color: p.primaryDark),
              ),
            ),
            const SizedBox(height: 16),
            if (items == 0)
              ScrollReveal(
                child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      isQuizCategory
                          ? Icons.quiz_outlined
                          : Icons.article_outlined,
                      size: 40,
                      color: p.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isQuizCategory ? 'No quizzes yet' : 'No notes yet',
                      style: ThemeAType.cardTitle(color: p.textDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Content updates automatically when admins publish new material.',
                      textAlign: TextAlign.center,
                      style: ThemeAType.body(color: p.textGrey, size: 13),
                    ),
                  ],
                ),
              ),
              )
            else if (isQuizCategory)
              ...category.quizzes.map(
                (quiz) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ScrollReveal(child: _QuizListTile(quiz: quiz)),
                ),
              )
            else
              ...category.articles.map(
                (article) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ScrollReveal(child: _ArticleListTile(article: article)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleListTile extends StatelessWidget {
  final InvestmentDocArticle article;

  const _ArticleListTile({required this.article});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      onTap: () => context.push(
        AppRoutes.documentArticlePath(article.categoryId, article.id),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LevelChip(label: article.level),
              const Spacer(),
              Text(
                '${article.readMinutes} min read',
                style: ThemeAType.label(size: 11, color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(article.title, style: ThemeAType.cardTitle(color: p.textDark)),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: ThemeAType.body(color: p.textGrey, size: 14),
          ),
          if (article.preview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              article.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ThemeAType.secondary(size: 12, color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizListTile extends StatelessWidget {
  final InvestmentDocQuiz quiz;

  const _QuizListTile({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final education = context.watch<EducationProvider>();
    final attempt = education.latestAttemptFor(quiz.id);
    final questionCount = quiz.questions.length;

    return GlassCard(
      onTap: () => context.push(AppRoutes.documentQuizPath(quiz.id)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.quiz_outlined, color: Color(0xFF14B8A6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: ThemeAType.cardTitle(color: p.textDark, size: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  questionCount > 0
                      ? '$questionCount questions · ${quiz.description}'
                      : quiz.description,
                  style: ThemeAType.body(color: p.textGrey, size: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attempt != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (attempt.percent >= 50 ? p.positive : p.negative)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Last score: ${attempt.score}/${attempt.total} (${attempt.percent}%)',
                      style: ThemeAType.label(
                        size: 10,
                        color: attempt.percent >= 50 ? p.positive : p.negative,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.play_circle_outline_rounded, color: ThemeA.primary),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;

  const _LevelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeA.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: ThemeAType.label(size: 10, color: ThemeA.primary),
      ),
    );
  }
}
