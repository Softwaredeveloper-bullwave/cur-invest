import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../models/bank_lookup_model.dart';
import 'bank_form_widgets.dart';
import 'searchable_dropdown_field.dart';

class BankSelectionSection extends StatefulWidget {
  const BankSelectionSection({
    super.key,
    required this.ifscController,
    required this.onIfscResolved,
    this.enabled = true,
  });

  final TextEditingController ifscController;
  final ValueChanged<IfscLookupResult?> onIfscResolved;
  final bool enabled;

  @override
  State<BankSelectionSection> createState() => BankSelectionSectionState();
}

class BankSelectionSectionState extends State<BankSelectionSection> {
  final _api = BullwaveApi.instance;

  BankOption? _bank;
  String? _state;
  String? _city;
  BankBranchOption? _branch;
  IfscLookupResult? _resolvedIfsc;
  bool _showBranchPicker = false;
  bool _lookupLoading = false;
  String? _lookupError;
  Timer? _lookupTimer;

  String? get selectedBankName => _resolvedIfsc?.bank ?? _branch?.bank ?? _bank?.name;

  @override
  void dispose() {
    _lookupTimer?.cancel();
    super.dispose();
  }

  void _clearResolution() {
    _resolvedIfsc = null;
    _lookupError = null;
    widget.onIfscResolved(null);
  }

  void _applyResolution(IfscLookupResult result, {BankBranchOption? branch}) {
    _resolvedIfsc = result;
    _branch = branch;
    _lookupError = null;
    widget.ifscController.text = result.ifsc;
    widget.onIfscResolved(result);
    setState(() {});
  }

  void _resetBranchPicker({bool includeBank = false, bool includeState = false, bool includeCity = false}) {
    if (includeBank) _bank = null;
    if (includeState || includeBank) _state = null;
    if (includeCity || includeState || includeBank) _city = null;
    _branch = null;
  }

  void _applyBranch(BankBranchOption branch) {
    _applyResolution(
      IfscLookupResult(
        ifsc: branch.ifsc,
        bank: branch.bank,
        bankCode: branch.bankCode,
        branch: branch.branch,
        city: branch.city,
        district: branch.district,
        state: branch.state,
        address: branch.address,
      ),
      branch: branch,
    );
  }

  Future<void> _lookupIfsc(String value) async {
    final code = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(code)) {
      setState(() {
        _clearResolution();
      });
      return;
    }

    setState(() {
      _lookupLoading = true;
      _lookupError = null;
    });
    try {
      final result = await _api.lookupIfsc(code);
      if (!mounted) return;
      _applyResolution(result);
      setState(() => _lookupLoading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _clearResolution();
        _lookupLoading = false;
        _lookupError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clearResolution();
        _lookupLoading = false;
        _lookupError = 'Could not find this IFSC. Check the code and try again.';
      });
    }
  }

  void _scheduleLookup(String value) {
    _lookupTimer?.cancel();
    _lookupTimer = Timer(const Duration(milliseconds: 450), () => _lookupIfsc(value));
  }

  void _onIfscChanged(String value) {
    final upper = value.toUpperCase();
    widget.ifscController.value = widget.ifscController.value.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
    _resetBranchPicker(includeBank: true);
    _scheduleLookup(upper);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionHeader(
          title: 'Bank & Branch',
          subtitle: 'Enter IFSC to see branch location, or find your branch below.',
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: widget.ifscController,
          label: 'IFSC Code',
          hint: 'e.g. HDFC0001234',
          readOnly: !widget.enabled,
          inputFormatters: [
            IfscInputFormatter(),
            LengthLimitingTextInputFormatter(11),
          ],
          onChanged: widget.enabled ? _onIfscChanged : null,
          suffixIcon: _lookupLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                  ),
                )
              : (_resolvedIfsc != null
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.green)
                  : IconButton(
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Look up IFSC',
                      onPressed: widget.enabled &&
                              RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                                  .hasMatch(widget.ifscController.text.trim())
                          ? () => _lookupIfsc(widget.ifscController.text)
                          : null,
                    )),
          validator: (value) {
            if (value == null || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value)) {
              return 'Enter a valid 11-character IFSC code';
            }
            if (_resolvedIfsc == null && !_lookupLoading) {
              return 'Look up IFSC to confirm branch location';
            }
            return null;
          },
        ),
        if (_lookupError != null) ...[
          const SizedBox(height: 10),
          Text(_lookupError!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
        ],
        if (_resolvedIfsc != null) ...[
          const SizedBox(height: 16),
          _IfscLocationCard(result: _resolvedIfsc!),
        ],
        const SizedBox(height: 20),
        InkWell(
          onTap: widget.enabled
              ? () => setState(() => _showBranchPicker = !_showBranchPicker)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showBranchPicker ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  _showBranchPicker ? 'Hide branch finder' : 'Find branch manually instead',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (_showBranchPicker) ...[
          const SizedBox(height: 8),
          SearchableDropdownField<BankOption>(
            label: 'Bank Name',
            hint: 'Search bank',
            valueLabel: _bank?.name,
            enabled: widget.enabled,
            loadItems: (query) => _api.getBanks(query: query),
            itemLabel: (item) => item.name,
            onSelected: (bank) {
              setState(() {
                _bank = bank;
                _resetBranchPicker(includeState: true);
              });
            },
          ),
          const SizedBox(height: 16),
          SearchableDropdownField<String>(
            label: 'State',
            hint: 'Search state',
            valueLabel: _state,
            enabled: widget.enabled && _bank != null,
            loadItems: (query) => _api.getBankStates(query: query),
            itemLabel: (item) => item,
            onSelected: (state) {
              setState(() {
                _state = state;
                _resetBranchPicker(includeCity: true);
              });
            },
          ),
          const SizedBox(height: 16),
          SearchableDropdownField<String>(
            label: 'City / District',
            hint: 'Search city or district',
            valueLabel: _city,
            enabled: widget.enabled && _bank != null && _state != null,
            loadItems: (query) => _api.getBankCities(
              bankCode: _bank!.code,
              state: _state!,
              query: query,
            ),
            itemLabel: (item) => item,
            onSelected: (city) {
              setState(() {
                _city = city;
                _branch = null;
              });
            },
          ),
          const SizedBox(height: 16),
          SearchableDropdownField<BankBranchOption>(
            label: 'Branch',
            hint: 'Search branch name',
            valueLabel: _branch?.branch,
            enabled: widget.enabled && _bank != null && _state != null && _city != null,
            loadItems: (query) => _api.searchBankBranches(
              bankCode: _bank!.code,
              state: _state!,
              city: _city!,
              query: query,
            ),
            itemLabel: (item) => '${item.branch} (${item.ifsc})',
            onSelected: _applyBranch,
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            'IFSC lookup shows branch location only. '
            'Bank verification uses Eko Penny-less when enabled, otherwise penny-drop.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}

class _IfscLocationCard extends StatelessWidget {
  const _IfscLocationCard({required this.result});

  final IfscLookupResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Branch location for this IFSC',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow('Bank', result.bank),
          _InfoRow('Branch', result.branch),
          _InfoRow('City', result.city),
          if (result.district.isNotEmpty && result.district != result.city)
            _InfoRow('District', result.district),
          _InfoRow('State', result.state),
          if (result.address.isNotEmpty) _InfoRow('Address', result.address),
          const Divider(height: 20),
          _InfoRow('IFSC', result.ifsc, emphasize: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
