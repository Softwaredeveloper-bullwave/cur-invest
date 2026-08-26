import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/news_image_url.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/crypto_models.dart';
import '../provider/crypto_market_provider.dart';

class CryptoNewsScreen extends StatefulWidget {
  const CryptoNewsScreen({super.key});

  @override
  State<CryptoNewsScreen> createState() => _CryptoNewsScreenState();
}

class _CryptoNewsScreenState extends State<CryptoNewsScreen> {
  String? _category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    await context.read<CryptoMarketProvider>().loadNews(
          category: _category,
          refresh: refresh,
        );
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Crypto News'),
      body: Consumer<CryptoMarketProvider>(
        builder: (context, provider, _) {
          final categories = ['All', ...provider.newsCategories];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: categories.map((cat) {
                    final selected =
                        (cat == 'All' && _category == null) || cat == _category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _category = cat == 'All' ? null : cat);
                          _load();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: provider.isLoading && provider.news.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: LoadingList(itemCount: 4),
                      )
                    : RefreshIndicator(
                        color: AppColors.brandCyan,
                        onRefresh: () => _load(refresh: true),
                        child: provider.news.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'No news available. Pull to refresh.',
                                      style: context.typeSecondary(14),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: provider.news.length,
                                itemBuilder: (_, i) {
                                  final article = provider.news[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _CryptoNewsCard(
                                      article: article,
                                      onTap: () =>
                                          _openArticle(article.externalUrl),
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CryptoNewsCard extends StatelessWidget {
  const _CryptoNewsCard({required this.article, required this.onTap});

  final CryptoNewsModel article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasImage = article.imageUrl.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: p.cardDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: hasImage
                      ? _NewsPhoto(
                          imageUrl: article.imageUrl,
                          category: article.category,
                        )
                      : _NewsImageFallback(category: article.category),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.primaryBorder),
                        ),
                        child: Text(
                          article.category,
                          style: context.typeLabel(10, p.primaryDark).copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(article.title, style: context.typeCardTitle(15)),
                    if (article.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        article.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.typeSecondary(13),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${article.source} · ${DateFormatter.display(article.publishedAt)}',
                            style: context.typeMuted(12),
                          ),
                        ),
                        if (article.externalUrl.isNotEmpty)
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 15,
                            color: p.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsPhoto extends StatefulWidget {
  const _NewsPhoto({required this.imageUrl, required this.category});

  final String imageUrl;
  final String category;

  @override
  State<_NewsPhoto> createState() => _NewsPhotoState();
}

class _NewsPhotoState extends State<_NewsPhoto> {
  late final List<String> _candidates;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final original = widget.imageUrl.trim();
    final proxied = resolveNewsImageUrl(original);
    _candidates = [
      if (proxied.isNotEmpty) proxied,
      if (original.isNotEmpty && original != proxied) original,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _candidates.length) {
      return _NewsImageFallback(category: widget.category);
    }
    final url = _candidates[_index];
    final isProxy = url.contains('news/image-proxy');
    return Image.network(
      url,
      key: ValueKey(url),
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      webHtmlElementStrategy: isProxy
          ? WebHtmlElementStrategy.never
          : WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFF1E2329),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return const ColoredBox(
            color: Color(0xFF1E2329),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _NewsImageFallback(category: widget.category);
      },
    );
  }
}

class _NewsImageFallback extends StatelessWidget {
  const _NewsImageFallback({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lower = category.toLowerCase();
    final accent = lower.contains('bitcoin')
        ? const Color(0xFFF7931A)
        : lower.contains('ethereum')
            ? const Color(0xFF627EEA)
            : p.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.35), p.card],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          color: accent.withValues(alpha: 0.7),
          size: 48,
        ),
      ),
    );
  }
}
