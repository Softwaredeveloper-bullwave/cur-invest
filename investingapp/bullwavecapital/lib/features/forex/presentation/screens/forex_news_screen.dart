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
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      tileColor: context.palette.card,
                                      title: Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                        '${article.source} · ${DateFormatter.display(article.publishedAt)}',
                                      ),
                                      leading: article.imageUrl.isEmpty
                                          ? const Icon(Icons.newspaper_rounded)
                                          : ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                resolveNewsImageUrl(article.imageUrl),
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => const Icon(Icons.newspaper_rounded),
                                              ),
                                            ),
                                      onTap: () {
                                        final uri = Uri.tryParse(article.externalUrl);
                                        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
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
