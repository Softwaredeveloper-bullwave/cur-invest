import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../models/crypto_models.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/crypto_mini_chart.dart';

const _cryptoPeriods = ['1H', '1D', '1W', '1M', '3M', '1Y', 'ALL'];

class CryptoDetailScreen extends StatefulWidget {
  const CryptoDetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  State<CryptoDetailScreen> createState() => _CryptoDetailScreenState();
}

class _CryptoDetailScreenState extends State<CryptoDetailScreen> {
  CryptoAssetModel? _asset;
  CryptoChartModel? _chart;
  String _period = '1D';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BullwaveApi.instance;
      final results = await Future.wait([
        api.getCryptoAsset(widget.assetId),
        api.getCryptoChart(widget.assetId, period: _period),
      ]);
      if (!mounted) return;
      setState(() {
        _asset = results[0] as CryptoAssetModel;
        _chart = results[1] as CryptoChartModel;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Market data is temporarily unavailable. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _changePeriod(String period) async {
    setState(() => _period = period);
    try {
      final chart = await BullwaveApi.instance.getCryptoChart(
        widget.assetId,
        period: period,
      );
      if (mounted) setState(() => _chart = chart);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Market data is temporarily unavailable. Please try again.');
      }
    }
  }

  Future<void> _paperTrade(String side) async {
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => _QuantityDialog(side: side, symbol: _asset?.symbol ?? ''),
    );
    if (qty == null || qty <= 0 || !mounted) return;
    final provider = context.read<CryptoMarketProvider>();
    final result = await provider.placePaperOrder(
      assetId: widget.assetId,
      side: side,
      quantity: qty,
    );
    if (!mounted) return;
    if (result != null) {
      AppSnackbar.success(context, 'PAPER TRADING order placed');
    } else {
      AppSnackbar.error(
        context,
        provider.error ?? 'Order failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final provider = context.watch<CryptoMarketProvider>();
    final inWatchlist = provider.isInWatchlist(widget.assetId);

    return Scaffold(
      appBar: CustomAppBar(
        title: _asset?.symbol ?? widget.assetId.toUpperCase(),
        actions: [
          IconButton(
            icon: Icon(inWatchlist ? Icons.star_rounded : Icons.star_outline_rounded),
            onPressed: () => provider.toggleWatchlist(widget.assetId),
          ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingList(itemCount: 4),
            )
          : _asset == null
              ? Center(child: Text(_error ?? 'Asset not found', style: context.typeSecondary(14)))
              : RefreshIndicator(
                  color: AppColors.brandCyan,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.primaryBorder),
                          ),
                          child: Text(
                            'PAPER TRADING — Simulated orders only',
                            style: context.typeLabel(12, p.primaryDark)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(_asset!.name, style: context.typeSecondary(14)),
                        const SizedBox(height: 4),
                        Text(
                          _formatUsd(_asset!.currentPrice),
                          style: context.typeHeading.copyWith(fontSize: 32),
                        ),
                        Text(
                          IndexFormatter.formatPercent(_asset!.change24hPct),
                          style: context.typeLabel(
                            14,
                            _asset!.isPositive ? p.positive : p.negative,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PeriodSelector(selected: _period, onSelected: _changePeriod),
                        const SizedBox(height: 12),
                        if (_chart != null && _chart!.prices.isNotEmpty)
                          SizedBox(
                            height: 200,
                            child: CryptoMiniChart(
                              values: _chart!.prices.map((e) => e.value).toList(),
                              positive: _asset!.isPositive,
                              width: MediaQuery.sizeOf(context).width - 32,
                              height: 200,
                              lineWidth: 2,
                            ),
                          ),
                        const SizedBox(height: 20),
                        _StatsGrid(asset: _asset!),
                        const SizedBox(height: 20),
                        if (_asset!.description.isNotEmpty) ...[
                          Text('About', style: context.typeSection(16)),
                          const SizedBox(height: 8),
                          Text(
                            _asset!.description.replaceAll(RegExp(r'<[^>]*>'), ' '),
                            style: context.typeBody(14),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _paperTrade('BUY'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.positive,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('BUY · PAPER TRADING'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _paperTrade('SELL'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: p.negative,
                                  side: BorderSide(color: p.negative),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('SELL · PAPER TRADING'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  static String _formatUsd(double value) {
    if (value >= 1) return '\$${value.toStringAsFixed(2)}';
    return '\$${value.toStringAsFixed(4)}';
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _cryptoPeriods.map((label) {
          final isSelected = label == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected
                  ? AppColors.brandOrange.withValues(alpha: 0.15)
                  : context.palette.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onSelected(label),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.brandOrange.withValues(alpha: 0.5)
                          : context.palette.borderLight,
                    ),
                  ),
                  child: Text(
                    label,
                    style: context.typeLabel(13, isSelected ? AppColors.brandOrange : null),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.asset});

  final CryptoAssetModel asset;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('24h High', _formatUsd(asset.high24h)),
      ('24h Low', _formatUsd(asset.low24h)),
      ('Volume', _compact(asset.volume)),
      ('Market Cap', _compact(asset.marketCap)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: stats
          .map(
            (s) => Container(
              padding: const EdgeInsets.all(12),
              decoration: context.palette.cardDecoration(radius: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.$1, style: context.typeSecondary(12)),
                  Text(s.$2, style: context.typeCardTitle(14)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static String _formatUsd(double v) => v >= 1 ? '\$${v.toStringAsFixed(2)}' : '\$${v.toStringAsFixed(4)}';

  static String _compact(double v) {
    if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.side, required this.symbol});

  final String side;
  final String symbol;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _controller = TextEditingController(text: '0.01');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.side} ${widget.symbol} · PAPER TRADING'),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final qty = double.tryParse(_controller.text.trim()) ?? 0;
            Navigator.pop(context, qty);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
