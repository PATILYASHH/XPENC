import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../data/providers.dart';

/// A searchable list of every currency the app knows. Picking one writes it to
/// settings; the whole app reformats immediately (see [CurrencyScope]).
class CurrencyPickerSheet extends ConsumerStatefulWidget {
  const CurrencyPickerSheet({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
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
    if (q.isEmpty) return kCurrencies;
    return kCurrencies
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.symbol.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = ref.watch(currencyProvider).code;
    final results = _filtered;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('Currency', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search name, code or symbol',
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
          const SizedBox(height: 8),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No currency matches "$_query".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final c = results[i];
                      final isSelected = c.code == selected;
                      return ListTile(
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
                        subtitle: Text(c.code),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded,
                                color: theme.colorScheme.primary)
                            : null,
                        selected: isSelected,
                        onTap: () async {
                          await ref.read(dbProvider).setCurrencyCode(c.code);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
