import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../core/widgets/nav_bar_inset.dart';
import 'custom_currency_sheet.dart';
import '../../core/l10n/l10n.dart';

/// A searchable list of every currency the app knows — the person's own
/// custom ones first — plus a way to make one it doesn't. Picking one writes
/// it to settings; the whole app reformats immediately (see [CurrencyScope]).
///
/// [initialCode]/[onSelected] let this same sheet be reused to pick an
/// arbitrary currency that has nothing to do with the app-wide setting — see
/// [pick] — without touching [Settings.currencyCode] at all.
class CurrencyPickerSheet extends ConsumerStatefulWidget {
  const CurrencyPickerSheet({this.initialCode, this.onSelected, super.key});

  final String? initialCode;
  final ValueChanged<Currency>? onSelected;

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const CurrencyPickerSheet(),
    );
  }

  /// Picks a currency without touching the app's home-currency setting — for
  /// a transaction or auto rule's own foreign-currency annotation (GitHub
  /// #85). Returns `null` if the sheet is dismissed without a pick.
  static Future<Currency?> pick(BuildContext context, {String? initialCode}) {
    return showAppSheet<Currency>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => CurrencyPickerSheet(
        initialCode: initialCode,
        onSelected: (c) => Navigator.of(context).pop(c),
      ),
    );
  }

  @override
  ConsumerState<CurrencyPickerSheet> createState() =>
      _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<CurrencyPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Currency> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return allCurrencies;
    return allCurrencies
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              c.symbol.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _choose(Currency c) async {
    if (widget.onSelected != null) {
      widget.onSelected!(c);
      return;
    }
    await ref.read(dbProvider).setCurrencyCode(c.code);
    if (mounted) Navigator.of(context).pop();
  }

  /// Makes a currency and picks it straight away. Everything it needs is
  /// read before the sheet opens — this one may not survive it.
  Future<void> _createCustom() async {
    final navigator = Navigator.of(context);
    final db = ref.read(dbProvider);
    final onSelected = widget.onSelected;
    final made = await showCustomCurrencySheet(context);
    if (made == null) return;
    if (onSelected != null) {
      onSelected(made);
      return;
    }
    await db.setCurrencyCode(made.code);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.initialCode ?? ref.watch(currencyProvider).code;
    // Rebuilds once a just-made currency joins the list.
    ref.watch(customCurrenciesProvider);
    final results = _filtered;
    final customCodes = {for (final c in customCurrencyList) c.code};

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Tr('Currency', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const AppIcon(Icons.search),
                  hintText: tr('Search name, code or symbol'),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 4),
            AppListTile(
              leading: const SizedBox(
                width: 40,
                child: Center(child: AppIcon(Icons.add_circle_outline_rounded)),
              ),
              title: const Tr('Create a custom currency'),
              subtitle: const Tr('For one that isn’t listed'),
              onTap: _createCustom,
            ),
            Flexible(
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr('No currency matches "{0}".', [_query]),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8).plusNavBar(context),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        final isSelected = c.code == selected;
                        return AppListTile(
                          leading: SizedBox(
                            width: 40,
                            child: Center(
                              child: Text(
                                c.symbol,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          title: Text(c.name),
                          subtitle: Text(
                            customCodes.contains(c.code)
                                ? tr('{0} · Custom', [c.code])
                                : c.code,
                          ),
                          trailing: isSelected
                              ? AppIcon(
                                  Icons.check_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          selected: isSelected,
                          onTap: () => _choose(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
