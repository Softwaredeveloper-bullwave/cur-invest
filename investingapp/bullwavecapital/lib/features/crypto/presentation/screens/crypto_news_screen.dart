import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
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

  Future<void> _load() async {
    await context.read<CryptoMarketProvider>().loadNews(category: _category);
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
                    final selected = (cat == 'All' && _category == null) || cat == _category;
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
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: provider.news.length,
                          itemBuilder: (_, i) {
                            final article = provider.news[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(article.title, style: context.typeCardTitle(15)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (article.summary.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      article.summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.typeSecondary(13),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '${article.source} · ${DateFormatter.display(article.publishedAt)}',
                                    style: context.typeMuted(12),
                                  ),
                                ],
                              ),
                              onTap: article.externalUrl.isNotEmpty
                                  ? () => launchUrl(Uri.parse(article.externalUrl))
                                  : null,
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
