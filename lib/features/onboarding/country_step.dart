import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/countries.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../settings/currency_picker_sheet.dart';

/// What the country step settled on: a country, and so its currency — or,
/// for a country the list doesn't carry, a currency picked directly.
class CurrencyChoice {
  CurrencyChoice.ofCountry(Country this.country) : currency = country.currency;

  const CurrencyChoice.ofCurrency(this.currency) : country = null;

  final Country? country;
  final Currency currency;
}

/// The amount the hero card previews, so the grouping a currency brings
/// (12,34,567 for the rupee, 1,234,567 elsewhere) shows before it's chosen.
const _sampleAmount = Money(123456700);

/// Onboarding's "Where do you live?" page — a searchable, A–Z country list
/// under a card that previews the parent currency the pick sets. Holds no
/// choice of its own: [selection] lives in the onboarding screen, which
/// writes it on the final tap like every other onboarding choice.
class CountryStep extends StatefulWidget {
  const CountryStep({
    required this.selection,
    required this.detected,
    required this.onSelect,
    super.key,
  });

  final CurrencyChoice? selection;

  /// The country the phone's region suggests, if we list it — labelled on
  /// the card while it's still the selection.
  final Country? detected;

  final ValueChanged<CurrencyChoice> onSelect;

  @override
  State<CountryStep> createState() => _CountryStepState();
}

class _CountryStepState extends State<CountryStep> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'CountryStep.search');
  String _query = '';

  /// While searching, the title and card fold away and the field sits on
  /// top — otherwise a short result list leaves the scroll nowhere to go,
  /// the card slides back down, and the matches end up under the keyboard.
  bool get _searching => _searchFocus.hasFocus || _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocus);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocus);
    _searchFocus.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchFocus() {
    if (_searchFocus.hasFocus && _scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
  }

  /// Back out of search: the full list, the card, no keyboard.
  void _exitSearch() {
    _search.clear();
    _query = '';
    _searchFocus.unfocus();
    setState(() {});
  }

  /// Picking leaves search and scrolls back to the card, so the choice —
  /// and how amounts will look — is confirmed in view.
  void _select(CurrencyChoice choice) {
    HapticFeedback.selectionClick();
    _exitSearch();
    widget.onSelect(choice);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _pickCurrencyDirectly() async {
    _exitSearch();
    final picked = await CurrencyPickerSheet.pick(
      context,
      // '' rather than null: null would tick the stored default currency,
      // which nobody chose yet.
      initialCode: widget.selection?.currency.code ?? '',
    );
    if (picked == null || !mounted) return;
    _select(CurrencyChoice.ofCurrency(picked));
  }

  /// A–Z headers interleaved with each letter's countries, or a flat list
  /// of matches while searching.
  List<_Entry> _entries() {
    final q = _query.trim().toLowerCase();
    final matches = kCountries.where((c) => c.matches(q)).toList();
    if (q.isNotEmpty) {
      return [
        for (var i = 0; i < matches.length; i++)
          _CountryEntry(
            matches[i],
            first: i == 0,
            last: i == matches.length - 1,
          ),
      ];
    }
    final entries = <_Entry>[];
    for (var i = 0; i < matches.length; i++) {
      final letter = _letterOf(matches[i]);
      final first = i == 0 || _letterOf(matches[i - 1]) != letter;
      final last =
          i == matches.length - 1 || _letterOf(matches[i + 1]) != letter;
      if (first) entries.add(_LetterEntry(letter));
      entries.add(_CountryEntry(matches[i], first: first, last: last));
    }
    return entries;
  }

  static String _letterOf(Country c) => c.name.substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = _entries();
    final selectedCode = widget.selection?.country?.code;
    final searching = _searching;

    return CustomScrollView(
      controller: _scroll,
      // Dragging results hides the keyboard only once there's a query —
      // with none, losing focus would drop out of search mid-drag.
      keyboardDismissBehavior: _query.isEmpty
          ? ScrollViewKeyboardDismissBehavior.manual
          : ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: searching
                ? const SizedBox(width: double.infinity, height: 16)
                : _intro(theme),
          ),
        ),
        PinnedHeaderSliver(
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: _SearchField(
                controller: _search,
                focusNode: _searchFocus,
                searching: searching,
                onChanged: (v) => setState(() => _query = v),
                onExit: _exitSearch,
              ),
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
              child: Text(
                'No country matches "${_query.trim()}".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) => switch (entries[i]) {
              _LetterEntry(:final letter) => _LetterHeader(letter),
              final _CountryEntry e => _CountryTile(
                country: e.country,
                first: e.first,
                last: e.last,
                selected: e.country.code == selectedCode,
                onTap: () => _select(CurrencyChoice.ofCountry(e.country)),
              ),
            },
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: _NotListedTile(onTap: _pickCurrencyDirectly),
          ),
        ),
      ],
    );
  }

  /// The title, the explainer and the card — folded away while searching.
  Widget _intro(ThemeData theme) {
    final cs = theme.colorScheme;
    final detected = widget.detected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Where do you live?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
            child: Text(
              'Your country sets your parent currency — every total '
              'in XPENC is shown in it. You can change it later in '
              'Settings.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          _ChoiceCard(
            choice: widget.selection,
            suggested:
                detected != null &&
                widget.selection?.country?.code == detected.code,
          ),
        ],
      ),
    );
  }
}

sealed class _Entry {
  const _Entry();
}

class _LetterEntry extends _Entry {
  const _LetterEntry(this.letter);

  final String letter;
}

class _CountryEntry extends _Entry {
  const _CountryEntry(this.country, {required this.first, required this.last});

  final Country country;

  /// First/last row of its group — they carry the group's rounded corners.
  final bool first;
  final bool last;
}

/// The big card above the list: the flag, the country, its currency, and
/// a sample amount in that currency's own format.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.choice, required this.suggested});

  final CurrencyChoice? choice;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final choice = this.choice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: choice == null
              ? _EmptyChoice(key: const ValueKey('none'))
              : _FilledChoice(
                  key: ValueKey(
                    '${choice.country?.code}:${choice.currency.code}',
                  ),
                  choice: choice,
                  suggested: suggested,
                ),
        ),
      ),
    );
  }
}

class _EmptyChoice extends StatelessWidget {
  const _EmptyChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        _FlagWell(
          child: IconWell(Icons.public_rounded, color: cs.primary, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick your country',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search or scroll the list below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilledChoice extends StatelessWidget {
  const _FilledChoice({
    required this.choice,
    required this.suggested,
    super.key,
  });

  final CurrencyChoice choice;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final country = choice.country;
    final currency = choice.currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _FlagWell(
              child: country != null
                  ? Text(country.flag, style: const TextStyle(fontSize: 38))
                  : Text(
                      currency.symbol,
                      maxLines: 1,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country?.name ?? currency.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    country != null
                        ? '${currency.name} · ${currency.code}'
                        : 'Chosen directly · ${currency.code}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Amounts will look like',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    MoneyFormat.symbolIn(_sampleAmount, currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (suggested) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              AppIcon(Icons.near_me_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Suggested from your phone's region",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The rounded square the card's flag (or symbol, or globe) sits in.
class _FlagWell extends StatelessWidget {
  const _FlagWell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      ),
    );
  }
}

/// The pill search field. In search mode its leading glyph turns into a
/// back arrow — the way out once the keyboard's gone but focus stayed.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
    required this.onExit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const none = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search country or currency',
        prefixIcon: searching
            ? IconButton(
                tooltip: 'Back',
                onPressed: onExit,
                icon: const AppIcon(Icons.arrow_back_rounded),
              )
            : const AppIcon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const AppIcon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: none,
        enabledBorder: none,
        focusedBorder: none,
      ),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  const _LetterHeader(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 18, 24, 8),
      child: Text(
        letter,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One country row. Rows of a letter form one rounded group (the first and
/// last carry its corners), split by inset dividers.
class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.first,
    required this.last,
    required this.selected,
    required this.onTap,
  });

  final Country country;
  final bool first;
  final bool last;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = country.currency;
    const corner = Radius.circular(20);
    final radius = BorderRadius.vertical(
      top: first ? corner : Radius.zero,
      bottom: last ? corner : Radius.zero,
    );
    final muted = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              if (!first)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 70,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            country.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected ? cs.onPrimaryContainer : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currency.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.1)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${currency.symbol} ${currency.code}',
                        maxLines: 1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: selected
                          ? Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: AppIcon(
                                Icons.check_circle_rounded,
                                color: cs.onPrimaryContainer,
                              ),
                            )
                          : const SizedBox.shrink(),
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

/// The way out for a country the list doesn't carry.
class _NotListedTile extends StatelessWidget {
  const _NotListedTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Center(
                  child: IconWell(
                    Icons.currency_exchange_rounded,
                    color: cs.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Don't see your country?",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose your currency directly instead.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
