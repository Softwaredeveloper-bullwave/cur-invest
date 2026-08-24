import 'package:flutter/material.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';

typedef SearchItemsLoader<T> = Future<List<T>> Function(String query);

class SearchableDropdownField<T> extends StatelessWidget {
  const SearchableDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.valueLabel,
    required this.loadItems,
    required this.itemLabel,
    required this.onSelected,
    this.enabled = true,
    this.validator,
  });

  final String label;
  final String hint;
  final String? valueLabel;
  final SearchItemsLoader<T> loadItems;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String? Function(String?)? validator;

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchSheet<T>(
        title: label,
        hint: hint,
        loadItems: loadItems,
        itemLabel: itemLabel,
      ),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final display = (valueLabel == null || valueLabel!.trim().isEmpty)
        ? hint
        : valueLabel!;

    return FormField<String>(
      key: ValueKey<String?>(valueLabel),
      validator: validator,
      initialValue: valueLabel,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimensions.paddingSm),
            InkWell(
              onTap: enabled ? () => _openPicker(context) : null,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: hint,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  errorText: field.errorText,
                  enabled: enabled,
                ),
                child: Text(
                  display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: valueLabel == null || valueLabel!.isEmpty
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet({
    required this.title,
    required this.hint,
    required this.loadItems,
    required this.itemLabel,
  });

  final String title;
  final String hint;
  final SearchItemsLoader<T> loadItems;
  final String Function(T item) itemLabel;

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  final _searchController = TextEditingController();
  List<T> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch('');
    _searchController.addListener(() => _fetch(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.loadItems(query);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load options. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final height = MediaQuery.of(context).size.height * 0.78;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.green),
                  )
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: colors.border.withValues(alpha: 0.6)),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        title: Text(widget.itemLabel(item)),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
