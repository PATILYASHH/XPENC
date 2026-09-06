import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'currency_picker_sheet.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// Settings > Currency. The parent currency (today's global
/// `Settings.currencyCode`, unchanged — this screen just gives it a home
/// alongside the rates that price every other currency against it) plus the
/// manually-maintained exchange-rate history that lets an account carry its
/// own currency (see `AppDatabase.latestRate`/`addCurrencyRate`).
class CurrencySettingsScreen extends ConsumerWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parentCurrency = ref.watch(currencyProvider);
    final ratesAsync = ref.watch(currencyRatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Currency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _sectionLabel(theme, 'Parent currency'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.payments_outlined),
              title: Text('${parentCurrency.symbol} ${parentCurrency.code}'),
              subtitle: Text(
                'Every total — Net Worth, Reports, Budgets — is shown in '
                'this currency.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => CurrencyPickerSheet.show(context, ref),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(theme, 'Exchange rates'),
          ratesAsync.when(
            data: (rates) => Card(
              child: Column(
                children: [
                  if (rates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No exchange rates yet. Add a currency below to give '
                        'an account its own currency — a bank account, '
                        'wallet or card can then carry that currency and '
                        'convert back to your parent currency using the '
                        'rate you enter here.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < rates.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 60, color: cs.outline),
                      _RateTile(rate: rates[i], parentCurrency: parentCurrency),
                    ],
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: const Text('Add a currency'),
                    onTap: () => _addCurrency(context, ref),
                  ),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load exchange rates.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCurrency(BuildContext context, WidgetRef ref) async {
    final picked = await CurrencyPickerSheet.pick(context);
    if (picked == null || !context.mounted) return;
    await showAddRateDialog(context, ref, picked.code);
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _RateTile extends ConsumerWidget {
  const _RateTile({required this.rate, required this.parentCurrency});

  final CurrencyRateRow rate;
  final Currency parentCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = currencyForCode(rate.currencyCode);
    final rateValue = rate.rateToBaseMicros / currencyRateScale;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SizedBox(
        width: 32,
        child: Center(
          child: Text(
            currency.symbol,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      title: Text(
        '1 ${currency.code} = ${rateValue.toStringAsFixed(4)} '
        '${parentCurrency.code}',
      ),
      subtitle: Text(
        'Updated ${_dateFormat.format(rate.effectiveAt)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showAddRateDialog(context, ref, rate.currencyCode),
    );
  }
}

/// Opens the "enter a rate" dialog for [currencyCode] and, if saved, records
/// it via [AppDatabase.addCurrencyRate]. Shared by "Add a currency" (a brand
/// new code) and tapping an existing rate row (a new historical entry for a
/// code already in use) — both just need a value and an effective date.
Future<void> showAddRateDialog(
  BuildContext context,
  WidgetRef ref,
  String currencyCode,
) async {
  final result = await showDialog<({int rateToBaseMicros, DateTime effectiveAt})>(
    context: context,
    builder: (_) => _AddRateDialog(currencyCode: currencyCode),
  );
  if (result == null) return;
  await ref
      .read(dbProvider)
      .addCurrencyRate(
        currencyCode: currencyCode,
        rateToBaseMicros: result.rateToBaseMicros,
        effectiveAt: result.effectiveAt,
      );
}

/// Same disposal-timing convention as `_MyIdDialog` in `settings_screen.dart`
/// — a `StatefulWidget` owning its own controller, not one disposed right
/// after `showDialog` resolves.
class _AddRateDialog extends StatefulWidget {
  const _AddRateDialog({required this.currencyCode});

  final String currencyCode;

  @override
  State<_AddRateDialog> createState() => _AddRateDialogState();
}

class _AddRateDialogState extends State<_AddRateDialog> {
  late final _rateController = TextEditingController();
  DateTime _effectiveAt = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = currencyForCode(widget.currencyCode);
    return AlertDialog(
      title: Text('${currency.name} rate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _rateController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Rate',
              hintText: 'e.g. 83.12',
              prefixText: '1 ${currency.code} = ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Effective date'),
            subtitle: Text(_dateFormat.format(_effectiveAt)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _effectiveAt = picked);
  }

  void _save() {
    final rate = double.tryParse(_rateController.text.trim());
    if (rate == null || rate <= 0) {
      setState(() => _error = 'Enter a valid rate.');
      return;
    }
    Navigator.of(context).pop((
      rateToBaseMicros: (rate * currencyRateScale).round(),
      effectiveAt: _effectiveAt,
    ));
  }
}
