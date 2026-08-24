import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../models/investment_doc_model.dart';
import '../provider/education_provider.dart';

class DocumentReaderScreen extends StatefulWidget {
  final String categoryId;
  final String articleId;

  const DocumentReaderScreen({
    super.key,
    required this.categoryId,
    required this.articleId,
  });

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  InvestmentDocArticle? _article;
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
    final article = await education.fetchArticle(
      widget.categoryId,
      widget.articleId,
      force: force,
    );
    if (!mounted) return;
    setState(() {
      _article = article;
      _loadError = article == null
          ? (education.error ?? 'Article not found')
          : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_loading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Article'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final article = _article;
    if (article == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Article'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError ?? 'Article not found',
                  textAlign: TextAlign.center,
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: article.title),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeA.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    article.level,
                    style: ThemeAType.label(size: 11, color: ThemeA.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${article.readMinutes} min read',
                  style: ThemeAType.label(size: 12, color: p.textMuted),
                ),
                const Spacer(),
                Text(
                  '${article.sections.length} sections',
                  style: ThemeAType.label(size: 11, color: p.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              article.summary,
              style: ThemeAType.body(color: p.textGrey, size: 15),
            ),
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: ThemeAType.sectionTitle(color: p.textDark, size: 16),
            ),
            const SizedBox(height: 12),
            ...article.sections.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ThemeA.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: ThemeAType.label(
                            size: 12,
                            color: ThemeA.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: ThemeAType.body(
                            color: p.textDark,
                            size: 15,
                          ).copyWith(height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
