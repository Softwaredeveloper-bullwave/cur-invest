import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/news_image_url.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/forex_models.dart';
import '../provider/forex_market_provider.dart';

class ForexNewsScreen extends StatefulWidget {
  const ForexNewsScreen({super.key});

  @override
  State<ForexNewsScreen> createState() => _ForexNewsScreenState();
}

class _ForexNewsScreenState extends State<ForexNewsScreen> {
  String? _category;

  static const _keywords = {
    'usd': ['usd', 'dollar', 'dxy', 'greenback', 'usdinr', 'usdjpy', 'eurusd', 'gbpusd'],
    'eur': ['eur', 'euro', 'eurusd', 'eurgbp', 'eurjpy', 'eurinr'],
    'gbp': ['gbp', 'pound', 'sterling', 'gbpusd', 'gbpjpy', 'gbpinr'],
    'jpy': ['jpy', 'yen', 'usdjpy', 'eurjpy', 'gbpjpy'],
    'inr': ['inr', 'rupee', 'usdinr', 'eurinr', 'gbpinr'],
    'majors': ['eurusd', 'gbpusd', 'usdjpy', 'usdchf', 'audusd', 'usdcad', 'nzdusd', 'major'],
    'central banks': ['fed', 'ecb', 'boe', 'boj', 'rbi', 'fomc', 'interest rate', 'rate hike', 'rate cut'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForexMarketProvider>().loadNews(refresh: true);
    });
  }

  bool _matches(ForexNewsModel article, String wanted) {
    if (article.category.toLowerCase() == wanted) return true;
    final blob =
        '${article.title} ${article.summary} ${article.category} ${article.relatedPairs.join(' ')}'
            .toLowerCase();
    final keys = _keywords[wanted];
    if (keys == null) return blob.contains(wanted);
    return keys.any(blob.contains);
  }

  List<ForexNewsModel> _filtered(List<ForexNewsModel> articles) {
    final wanted = _category?.toLowerCase();
    if (wanted == null || wanted == 'all') return articles;
    final matched = articles.where((a) => _matches(a, wanted)).toList();
    return matched.isEmpty ? articles : matched;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Forex News'),
      body: Consumer<ForexMarketProvider>(
        builder: (context, provider, _) {
          final chips = provider.newsCategories.isEmpty
              ? const ['All', 'USD', 'EUR', 'GBP', 'INR', 'Market Analysis']
              : provider.newsCategories;
          final visible = _filtered(provider.news);
          return Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: chips.map((cat) {
                    final selected = (cat == 'All' && _category == null) || cat == _category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = cat == 'All' ? null : cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (provider.error != null && provider.news.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: provider.isLoading && provider.news.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: LoadingList(itemCount: 4))
                    : RefreshIndicator(
                        color: AppColors.brandCyan,
                        onRefresh: () => provider.loadNews(refresh: true),
                        child: visible.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('No forex headlines. Pull to refresh.')),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: visible.length,
                                itemBuilder: (_, i) {
                                  final article = visible[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ForexNewsCard(
                                      key: ValueKey(article.id),
                                      article: article,
                                      onTap: () {
                                        final uri = Uri.tryParse(article.externalUrl);
                                        if (uri != null) {
                                          launchUrl(
                                            uri,
                                            mode: LaunchMode.externalApplication,
                                          );
                                        }
                                      },
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

class _ForexNewsCard extends StatelessWidget {
  const _ForexNewsCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  final ForexNewsModel article;
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
                          key: ValueKey('${article.id}-${article.imageUrl}'),
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
  const _NewsPhoto({
    super.key,
    required this.imageUrl,
    required this.category,
  });

  final String imageUrl;
  final String category;

  @override
  State<_NewsPhoto> createState() => _NewsPhotoState();
}

class _NewsPhotoState extends State<_NewsPhoto> {
  List<String> _candidates = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _candidates = _urlsFor(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _NewsPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _index = 0;
      _candidates = _urlsFor(widget.imageUrl);
    }
  }

  List<String> _urlsFor(String imageUrl) {
    final original = imageUrl.trim();
    final proxied = resolveNewsImageUrl(original);
    return [
      if (!kIsWeb && original.isNotEmpty) original,
      if (proxied.isNotEmpty) proxied,
      if (kIsWeb && original.isNotEmpty && original != proxied) original,
    ];
  }

  static const _loading = ColoredBox(
    color: Color(0xFF1E2329),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_index >= _candidates.length) {
      return _NewsImageFallback(category: widget.category);
    }
    final url = _candidates[_index];
    return CachedNetworkImage(
      imageUrl: url,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => _loading,
      errorWidget: (_, _, _) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return _loading;
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
    final accent = lower == 'usd'
        ? const Color(0xFF22C55E)
        : lower == 'eur'
            ? const Color(0xFF3B82F6)
            : lower == 'gbp'
                ? const Color(0xFF8B5CF6)
                : lower == 'inr'
                    ? const Color(0xFFF59E0B)
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
