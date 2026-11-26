import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/countries.dart';
import '../../core/country_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/providers.dart';
import '../../core/l10n/l10n.dart';

/// Settings → Country: where the user lives. Picking one turns that
/// country's features on by default — UPI for India, Venmo and Cash App
/// for the US, Revolut in Europe — and decides whether voice add (double
/// tap ➕) is offered. Every payment method can still be flipped by hand in
/// Settings → Payment methods. The main currency is its own setting.
class CountrySettingsScreen extends ConsumerStatefulWidget {
  const CountrySettingsScreen({super.key});

  @override
  ConsumerState<CountrySettingsScreen> createState() =>
      _CountrySettingsScreenState();
}

class _CountrySettingsScreenState extends ConsumerState<CountrySettingsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(homeCountryProvider);
    final countries = [
      for (final c in kCountries)
        if (c.matches(_query)) c,
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Country')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32).plusNavBar(context),
        children: [
          Tr(
            'Where you live decides which features are on to start with — '
            'UPI and India\'s tools in India, Venmo in the US, and so on. '
            'You can still change each payment method yourself.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: tr('Search countries'),
              prefixIcon: const AppIcon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          AppCard(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, c) in countries.indexed) ...[
                  if (i > 0) Divider(height: 1, indent: 60),
                  AppListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name),
                    subtitle: Text(c.currencyCode),
                    trailing: c.code == current
                        ? AppIcon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: c.code == current ? null : () => _pick(c),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(Country country) async {
    final messenger = ScaffoldMessenger.of(context);
    final d = paymentDefaultsFor(country.code);
    final on = [
      if (d.upi) 'UPI',
      if (d.paypal) 'PayPal',
      if (d.venmo) 'Venmo',
      if (d.cashapp) 'Cash App',
      if (d.revolut) 'Revolut',
    ];
    final currency = ref.read(currencyProvider);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${country.flag}  ${country.name}'),
        content: Text(
          [
            on.isEmpty
                ? tr('Payment methods: none on to start with.')
                : tr('Payment methods on: {0}.', [on.join(', ')]),
            if (isIndia(country.code)) tr("India's tools and voice add on."),
            if (currency.code != country.currencyCode)
              tr(
                'Your main currency stays {0} — change it in Settings → '
                'Currency.',
                [currency.code],
              ),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Tr('Change'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dbProvider).setCountry(country.code);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(tr('Country set to {0}', [country.name]))),
      );
  }
}
