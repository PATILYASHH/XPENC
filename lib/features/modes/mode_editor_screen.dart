import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/icon_picker_sheet.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/modes_db.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../accounts/account_look_fields.dart';
import '../settings/currency_picker_sheet.dart';
import 'mode_modules.dart';
import 'mode_widgets.dart';

/// The bottom-bar destinations a mode can put in its two slots — the same
/// ids `Settings.bottomNavSlots` uses (see `AppShell`).
const modeNavSlotChoices = <String, String>{
  'transactions': 'Transactions',
  'persons': 'Persons',
  'calendar': 'Calendar',
  'budgets': 'Budgets',
  'accounts': 'Accounts',
  'stats': 'Stats',
  'payees': 'Payees',
};

/// Creates a mode (from a [ModePreset]) or edits one: what it's called,
/// when it runs, what it may spend from, what it tags, and what the app
/// shows while it's the focus.
class ModeEditorScreen extends ConsumerStatefulWidget {
  const ModeEditorScreen({this.modeId, this.presetKey, super.key});

  /// Null for a new mode.
  final int? modeId;
  final String? presetKey;

  @override
  ConsumerState<ModeEditorScreen> createState() => _ModeEditorScreenState();
}

class _ModeEditorScreenState extends ConsumerState<ModeEditorScreen> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  late String _iconKey;
  late int _colorValue;
  DateTime? _start;
  DateTime? _end;
  String? _currencyCode;
  int? _groupId;
  String? _slotLeft;
  String? _slotRight;
  Set<String> _modules = {};
  Set<int> _accountIds = {};
  Set<int> _categoryIds = {};
  Set<int> _tagIds = {};

  /// Made here but only written once the mode itself is saved — a new mode
  /// has no id for them to point at yet.
  final List<({String name, String iconKey})> _newCategories = [];
  final List<({String name, bool auto})> _newTags = [];

  final _daily = TextEditingController();
  final _perSpend = TextEditingController();

  /// What each picked account gives the mode — see `ModeAccounts.allocation`.
  final Map<int, TextEditingController> _allocations = {};

  /// Category caps, by category id.
  final Map<int, TextEditingController> _limits = {};

  /// Who's on the trip — the mode's group members.
  Set<int> _people = {};

  bool _wallet = false;
  int? _walletSourceId;
  final _walletAmount = TextEditingController();

  /// The wallet once the mode has made it — its setup is fixed from then.
  int? _walletMade;

  /// Planned costs as edited; saved ones keep their id.
  final List<_PlannedDraft> _planned = [];
  final Set<int> _removedPlanned = {};

  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.modeId == null;

  @override
  void initState() {
    super.initState();
    final preset = ModePreset.byKey(widget.presetKey);
    _name.text = preset.name;
    _iconKey = preset.iconKey;
    _colorValue = preset.colorValue;
    // Copies: the editor changes these sets, and a preset's are constant.
    _modules = {...(preset.modules.isEmpty ? ModeModule.keys : preset.modules)};
    final slots = preset.navSlots?.split(',');
    if (slots != null && slots.length == 2) {
      _slotLeft = slots[0];
      _slotRight = slots[1];
    }
    if (_isNew) {
      _loaded = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final id = widget.modeId!;
    final mode = await db.modeById(id);
    final accounts = await db.modeAccountIds(id);
    final tags = await db.modeTagIds(id);
    final cats = {
      for (final l in await (db.select(
        db.modeCategories,
      )..where((l) => l.modeId.equals(id))).get())
        l.categoryId,
    };
    final accountRows = await (db.select(
      db.modeAccounts,
    )..where((l) => l.modeId.equals(id))).get();
    final limitRows = await (db.select(
      db.modeCategoryLimits,
    )..where((l) => l.modeId.equals(id))).get();
    final plannedRows = await (db.select(
      db.modePlannedCosts,
    )..where((c) => c.modeId.equals(id))).get();
    final people = await db.modePeopleIds(id);
    if (!mounted) return;
    if (mode == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _name.text = mode.name;
      _iconKey = mode.iconKey;
      _colorValue = mode.colorValue;
      _start = mode.startDate;
      _end = mode.endDate;
      _currencyCode = mode.currencyCode;
      _groupId = mode.groupId;
      final b = mode.budget;
      _budget.text = b == null
          ? ''
          : b.paise % 100 == 0
          ? '${b.paise ~/ 100}'
          : b.rupees.toStringAsFixed(2);
      final slots = mode.navSlots?.split(',');
      _slotLeft = slots != null && slots.length == 2 ? slots[0] : null;
      _slotRight = slots != null && slots.length == 2 ? slots[1] : null;
      // Copies — the chips change them in place.
      _modules = {...modeModuleKeys(mode)};
      _accountIds = {...accounts};
      _categoryIds = {...cats};
      _tagIds = {...tags};
      for (final r in accountRows) {
        if (r.allocation != null) {
          _allocCtrl(r.accountId).text = _moneyText(r.allocation);
        }
      }
      for (final r in limitRows) {
        _limits[r.categoryId] = TextEditingController(
          text: _moneyText(r.amount),
        );
      }
      _daily.text = _moneyText(mode.dailyLimit);
      _perSpend.text = _moneyText(mode.spendLimit);
      _people = {...people};
      _walletMade = mode.walletAccountId;
      _wallet = mode.walletAmount != null;
      _walletSourceId = mode.walletSourceAccountId;
      _walletAmount.text = _moneyText(mode.walletAmount);
      plannedRows.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _planned.addAll([
        for (final r in plannedRows)
          _PlannedDraft(
            id: r.id,
            name: r.name,
            amount: r.amount,
            categoryId: r.categoryId,
            paid: r.transactionId != null,
          ),
      ]);
      _loaded = true;
    });
  }

  TextEditingController _allocCtrl(int accountId) =>
      _allocations.putIfAbsent(accountId, TextEditingController.new);

  static String _moneyText(Money? m) => m == null
      ? ''
      : m.paise % 100 == 0
      ? '${m.paise ~/ 100}'
      : m.rupees.toStringAsFixed(2);

  /// [c]'s amount, null when empty; a typo is an error naming [label].
  static Money? _moneyOf(TextEditingController c, String label) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final m = Money.tryParse(raw);
    if (m == null) throw ArgumentError("The $label isn't a number.");
    return m;
  }

  /// The people now become the linked group's members.
  Future<void> _linkGroup(int? groupId) async {
    setState(() => _groupId = groupId);
    if (groupId == null) return;
    final members = await ref.read(dbProvider).watchGroupMembers(groupId).first;
    if (!mounted) return;
    setState(() => _people = {for (final p in members) p.id});
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _daily.dispose();
    _perSpend.dispose();
    _walletAmount.dispose();
    for (final c in [..._allocations.values, ..._limits.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final rawBudget = _budget.text.trim();
    final budget = rawBudget.isEmpty ? null : Money.tryParse(rawBudget);
    if (rawBudget.isNotEmpty && budget == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("That budget isn't a number")),
      );
      return;
    }
    final navSlots = _slotLeft != null && _slotRight != null
        ? '$_slotLeft,$_slotRight'
        : null;
    final Money? daily;
    final Money? perSpend;
    final Money? walletAmount;
    final allocations = <int, Money>{};
    final limits = <int, Money>{};
    try {
      daily = _moneyOf(_daily, 'daily limit');
      perSpend = _moneyOf(_perSpend, 'per-spend limit');
      walletAmount = _wallet && _walletMade == null
          ? _moneyOf(_walletAmount, 'wallet amount')
          : null;
      for (final id in _accountIds) {
        final c = _allocations[id];
        final m = c == null ? null : _moneyOf(c, 'allocation');
        if (m != null) allocations[id] = m;
      }
      for (final e in _limits.entries) {
        final m = _moneyOf(e.value, 'category limit');
        if (m != null) limits[e.key] = m;
      }
    } on ArgumentError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
      return;
    }
    final walletSource = _wallet && _walletMade == null
        ? _walletSourceId
        : null;
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    try {
      int id;
      if (_isNew) {
        id = await db.addMode(
          name: _name.text,
          iconKey: _iconKey,
          colorValue: _colorValue,
          startDate: _start,
          endDate: _end,
          budget: budget,
          currencyCode: _currencyCode,
          groupId: _groupId,
          navSlots: navSlots,
          modules: encodeModeModules(_modules),
          accountIds: _accountIds,
          categoryIds: _categoryIds,
          tagIds: _tagIds,
          allocations: allocations,
          categoryLimits: limits,
          dailyLimit: daily,
          spendLimit: perSpend,
          walletSourceAccountId: walletSource,
          walletAmount: walletAmount,
          personIds: _people,
        );
      } else {
        id = widget.modeId!;
        await db.updateMode(
          id,
          name: _name.text,
          iconKey: _iconKey,
          colorValue: _colorValue,
          startDate: _start,
          endDate: _end,
          budget: budget,
          currencyCode: _currencyCode,
          groupId: _groupId,
          navSlots: navSlots,
          modules: encodeModeModules(_modules),
          accountIds: _accountIds,
          categoryIds: _categoryIds,
          tagIds: _tagIds,
          allocations: allocations,
          categoryLimits: limits,
          dailyLimit: daily,
          spendLimit: perSpend,
          walletSourceAccountId: walletSource,
          walletAmount: walletAmount,
          personIds: _people,
        );
      }
      for (final pid in _removedPlanned) {
        await db.deletePlannedCost(pid);
      }
      for (final p in _planned) {
        if (p.id == null) {
          await db.addPlannedCost(
            modeId: id,
            name: p.name,
            amount: p.amount,
            categoryId: p.categoryId,
          );
        } else {
          await db.updatePlannedCost(
            p.id!,
            name: p.name,
            amount: p.amount,
            categoryId: p.categoryId,
          );
        }
      }
      for (final c in _newCategories) {
        await db.addModeCategory(
          modeId: id,
          name: c.name,
          kind: CategoryKind.expense,
          colorValue: _colorValue,
          iconKey: c.iconKey,
        );
      }
      final newAuto = <int>[];
      for (final t in _newTags) {
        final tagId = await db.addModeTag(
          modeId: id,
          name: t.name,
          colorValue: _colorValue,
        );
        if (t.auto) newAuto.add(tagId);
      }
      await db.addModeAutoTags(id, newAuto);
      if (!mounted) return;
      if (_isNew) {
        await _offerStart(id);
        if (!mounted) return;
        router.pushReplacement('/mode/$id');
      } else {
        router.pop();
      }
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not save')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A new mode that isn't waiting for a later start date can go ON now.
  Future<void> _offerStart(int id) async {
    final today = DateUtils.dateOnly(DateTime.now());
    if (_start != null && _start!.isAfter(today)) return;
    final mode = await ref.read(dbProvider).modeById(id);
    if (mode == null || !mounted) return;
    final start = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${mode.name} now?'),
        content: const Text(
          'While it is ON, everything you add joins it and the app shows '
          'only what you picked for it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start now'),
          ),
        ],
      ),
    );
    if (start == true && mounted) {
      await startModeWithConfirm(context, ref, mode);
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? first}) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? first ?? DateTime.now(),
        firstDate: first ?? DateTime(2000),
        lastDate: DateTime(2100),
      );

  Future<void> _addCategory() async {
    final result = await _askName(
      title: 'New category for this mode',
      hint: 'e.g. Beach shacks',
      withIcon: true,
    );
    if (result == null) return;
    setState(
      () => _newCategories.add((name: result.name, iconKey: result.iconKey)),
    );
  }

  Future<void> _addTag() async {
    final result = await _askName(
      title: 'New tag for this mode',
      hint: 'e.g. Goa',
      withIcon: false,
    );
    if (result == null) return;
    final taken = (ref.read(tagsProvider).valueOrNull ?? const []).any(
      (t) => t.name.toLowerCase() == result.name.toLowerCase(),
    );
    if (taken || _newTags.any((t) => t.name == result.name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('There is already a tag called ${result.name}')),
      );
      return;
    }
    setState(() => _newTags.add((name: result.name, auto: true)));
  }

  Future<({String name, String iconKey})?> _askName({
    required String title,
    required String hint,
    required bool withIcon,
  }) async {
    final controller = TextEditingController();
    var iconKey = 'other';
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: Row(
            children: [
              if (withIcon) ...[
                IconButton.filledTonal(
                  tooltip: 'Icon',
                  onPressed: () async {
                    final picked = await showIconPickerSheet(
                      context,
                      selected: iconKey,
                      accentColor: Color(_colorValue),
                      allowEmoji: true,
                    );
                    if (picked != null) setLocal(() => iconKey = picked);
                  },
                  icon: KeyIcon(iconKey, color: Color(_colorValue)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: withIcon ? 40 : 30,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: hint),
                  onSubmitted: (_) => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty) return null;
    return (name: name, iconKey: iconKey);
  }

  /// Picks a category to cap — everyday ones and this mode's own.
  Future<int?> _pickCategory({Set<int> exclude = const {}}) {
    final everyday =
        ref.read(categoriesProvider(CategoryKind.expense)).valueOrNull ?? [];
    final own = [
      for (final c in ref.read(modeOwnCategoriesProvider).valueOrNull ?? [])
        if (c.modeId == widget.modeId && c.kind == CategoryKind.expense) c,
    ];
    final choices = [
      for (final c in [...own, ...everyday])
        if (c.parentId == null && !exclude.contains(c.id)) c,
    ];
    return showAppSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in choices)
                AppListTile(
                  leading: KeyIcon(c.iconKey, color: Color(c.colorValue)),
                  title: Text(c.name),
                  onTap: () => Navigator.of(context).pop(c.id),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addLimit() async {
    final id = await _pickCategory(exclude: _limits.keys.toSet());
    if (id == null || !mounted) return;
    setState(() => _limits[id] = TextEditingController());
  }

  /// Adds or edits a planned cost ([index] null = new).
  Future<void> _editPlanned([int? index]) async {
    final draft = index == null ? null : _planned[index];
    final name = TextEditingController(text: draft?.name ?? '');
    final amount = TextEditingController(text: _moneyText(draft?.amount));
    var categoryId = draft?.categoryId;
    final cats = ref.read(categoryMapProvider);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(draft == null ? 'Planned cost' : 'Edit planned cost'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: draft == null,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What',
                  hintText: 'Hotel, tickets…',
                  counterText: '',
                ),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${MoneyFormat.currency.symbol} ',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const AppIcon(Icons.category_outlined, size: 18),
                  label: Text(cats[categoryId]?.name ?? 'Category (optional)'),
                  onPressed: () async {
                    final picked = await _pickCategory();
                    if (picked != null) setLocal(() => categoryId = picked);
                  },
                ),
              ),
            ],
          ),
          actions: [
            if (index != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
            if (index != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    final removed = _planned.removeAt(index);
                    if (removed.id != null) _removedPlanned.add(removed.id!);
                  });
                  Navigator.of(context).pop(false);
                },
                child: const Text('Remove'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    final money = Money.tryParse(amount.text.trim());
    name.dispose();
    amount.dispose();
    if (ok != true || !mounted) return;
    if (text.isEmpty || money == null || !money.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give it a name and an amount')),
      );
      return;
    }
    setState(() {
      final next = _PlannedDraft(
        id: draft?.id,
        name: text,
        amount: money,
        categoryId: categoryId,
        paid: draft?.paid ?? false,
      );
      if (index == null) {
        _planned.add(next);
      } else {
        _planned[index] = next;
      }
    });
  }

  Widget _moneyField(TextEditingController c, String label, {String? hint}) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: '${MoneyFormat.currency.symbol} ',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (!_loaded) {
      return Scaffold(
        appBar: AppTopBar(title: const Text('Edit mode')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final moneyInOutGoals = ref.watch(moneyInOutGoalIdsProvider);
    final accounts = [
      for (final a in ref.watch(accountsProvider).valueOrNull ?? const [])
        if (takesMoneyInOut(a, moneyInOutGoals)) a,
    ];
    final everydayCats = [
      for (final c
          in ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ??
              const <CategoryRow>[])
        if (c.parentId == null) c,
    ];
    final ownCats = [
      for (final c
          in ref.watch(modeOwnCategoriesProvider).valueOrNull ??
              const <CategoryRow>[])
        if (widget.modeId != null && c.modeId == widget.modeId) c,
    ];
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <TagRow>[];
    final everydayTags = [
      for (final t in tags)
        if (t.modeId == null) t,
    ];
    final ownTags = [
      for (final t in tags)
        if (widget.modeId != null && t.modeId == widget.modeId) t,
    ];
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final persons = ref.watch(personsProvider).valueOrNull ?? const [];
    final cats = ref.watch(categoryMapProvider);
    final day = DateFormat('d MMM yyyy');
    final currency = _currencyCode == null
        ? null
        : currencyForCode(_currencyCode);

    Widget hint(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );

    return Scaffold(
      appBar: AppTopBar(
        title: Text(_isNew ? 'New mode' : 'Edit mode'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
        children: [
          // ── Look ──────────────────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showIconPickerSheet(
                    context,
                    selected: _iconKey,
                    accentColor: Color(_colorValue),
                    allowEmoji: true,
                  );
                  if (picked != null) setState(() => _iconKey = picked);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(_colorValue),
                    shape: BoxShape.circle,
                  ),
                  child: KeyIcon(_iconKey, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Goa trip',
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AccountColorPicker(
            selected: _colorValue,
            onChanged: (v) => setState(() => _colorValue = v),
          ),

          // ── When and how much ─────────────────────────────────────────
          modeSectionLabel(theme, 'WHEN'),
          hint(
            'Optional. With dates it switches itself on on the first day and '
            'off after the last.',
          ),
          AppCard(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                AppListTile(
                  leading: const AppIcon(Icons.flight_takeoff_rounded),
                  title: const Text('Starts'),
                  subtitle: Text(
                    _start == null ? 'When you start it' : day.format(_start!),
                  ),
                  trailing: _start == null
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const AppIcon(Icons.close_rounded),
                          onPressed: () => setState(() => _start = null),
                        ),
                  onTap: () async {
                    final d = await _pickDate(_start);
                    if (d == null) return;
                    setState(() {
                      _start = d;
                      if (_end != null && _end!.isBefore(d)) _end = null;
                    });
                  },
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                AppListTile(
                  leading: const AppIcon(Icons.flight_land_rounded),
                  title: const Text('Ends'),
                  subtitle: Text(
                    _end == null ? 'When you end it' : day.format(_end!),
                  ),
                  trailing: _end == null
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const AppIcon(Icons.close_rounded),
                          onPressed: () => setState(() => _end = null),
                        ),
                  onTap: () async {
                    final d = await _pickDate(_end ?? _start, first: _start);
                    if (d != null) setState(() => _end = d);
                  },
                ),
              ],
            ),
          ),
          modeSectionLabel(theme, 'BUDGET'),
          TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Total to spend (optional)',
              prefixText: '${MoneyFormat.currency.symbol} ',
            ),
          ),
          hint(
            'Left empty, the budget is what you allocate from your accounts '
            'below.',
          ),
          modeSectionLabel(theme, 'LIMITS'),
          hint(
            'Going over one asks before saving — it never stops you. Alerts '
            'at 80% and 100%.',
          ),
          Row(
            children: [
              Expanded(child: _moneyField(_daily, 'Per day')),
              const SizedBox(width: 12),
              Expanded(child: _moneyField(_perSpend, 'Per spend')),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in _limits.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  KeyIcon(
                    cats[e.key]?.iconKey ?? 'other',
                    color: Color(
                      cats[e.key]?.colorValue ?? cs.primary.toARGB32(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cats[e.key]?.name ?? 'Category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 130, child: _moneyField(e.value, 'Limit')),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const AppIcon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _limits.remove(e.key)?.dispose();
                    }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const AppIcon(Icons.add_rounded, size: 18),
              label: const Text('Limit a category'),
              onPressed: _addLimit,
            ),
          ),
          modeSectionLabel(theme, 'CURRENCY'),
          AppCard(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: AppListTile(
              leading: const AppIcon(Icons.public_rounded),
              title: const Text('Spending in'),
              subtitle: Text(
                currency == null
                    ? 'Your home currency'
                    : '${currency.code} · ${currency.name} — '
                          'new spends note the amount in it',
              ),
              trailing: currency == null
                  ? const AppIcon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Home currency',
                      icon: const AppIcon(Icons.close_rounded),
                      onPressed: () => setState(() => _currencyCode = null),
                    ),
              onTap: () async {
                final picked = await CurrencyPickerSheet.pick(
                  context,
                  initialCode: _currencyCode ?? MoneyFormat.currency.code,
                );
                if (picked == null) return;
                setState(
                  () => _currencyCode = picked.code == MoneyFormat.currency.code
                      ? null
                      : picked.code,
                );
              },
            ),
          ),

          // ── Limits ────────────────────────────────────────────────────
          modeSectionLabel(theme, 'PEOPLE'),
          hint(
            "Who's with you. Inside the mode, Persons shows only them, "
            'starting from zero — and Add can split a bill with them.',
          ),
          _chips([
            for (final p in persons)
              FilterChip(
                label: Text(p.name),
                selected: _people.contains(p.id),
                onSelected: (v) => setState(
                  () => v ? _people.add(p.id) : _people.remove(p.id),
                ),
              ),
            if (persons.isEmpty)
              Text(
                'Add people in Persons first.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ]),
          modeSectionLabel(theme, 'PAYS WITH'),
          hint(
            'Only these accounts are offered while it is ON (none = any). Set '
            "how much of each is for the trip: while it's ON the account "
            "shows what's left of that, after it the real balance.",
          ),
          _chips([
            for (final a in accounts)
              if (a.id != _walletMade)
                FilterChip(
                  label: Text(a.name),
                  selected: _accountIds.contains(a.id),
                  onSelected: (v) => setState(
                    () => v ? _accountIds.add(a.id) : _accountIds.remove(a.id),
                  ),
                ),
          ]),
          const SizedBox(height: 8),
          for (final a in accounts)
            if (_accountIds.contains(a.id) && a.id != _walletMade)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: _moneyField(
                        _allocCtrl(a.id),
                        'For the trip',
                        hint: 'All of it',
                      ),
                    ),
                  ],
                ),
              ),
          modeSectionLabel(theme, 'TRIP WALLET'),
          if (_walletMade != null)
            hint(
              'Made when it started: '
              '${accounts.where((a) => a.id == _walletMade).firstOrNull?.name ?? 'the wallet'}. '
              'Its leftover goes back from the summary.',
            )
          else ...[
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: AppSwitchListTile(
                value: _wallet,
                onChanged: (v) => setState(() => _wallet = v),
                title: const Text('Fill a trip wallet when it starts'),
                subtitle: const Text(
                  'A cash account for the trip — what is left goes back at '
                  'the end',
                ),
              ),
            ),
            if (_wallet) ...[
              const SizedBox(height: 12),
              _moneyField(_walletAmount, 'Amount'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: accounts.any((a) => a.id == _walletSourceId)
                    ? _walletSourceId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'From'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _walletSourceId = v),
              ),
            ],
          ],
          modeSectionLabel(theme, 'PLANNED COSTS'),
          hint(
            'Known costs (the hotel, the tickets) — counted against the '
            'budget before you pay them.',
          ),
          if (_planned.isNotEmpty)
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, p) in _planned.indexed) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 16, color: cs.outline),
                    AppListTile(
                      onTap: () => _editPlanned(i),
                      title: Text(p.name),
                      subtitle: Text(
                        [
                          if (p.paid) 'Paid',
                          ?cats[p.categoryId]?.name,
                        ].join(' · '),
                      ),
                      trailing: Text(MoneyFormat.symbol(p.amount)),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const AppIcon(Icons.add_rounded, size: 18),
              label: const Text('Add a planned cost'),
              onPressed: _editPlanned,
            ),
          ),
          modeSectionLabel(theme, 'CATEGORIES'),
          hint(
            'Only these are offered while it is ON (with their '
            'subcategories). None = all. Its own categories always are.',
          ),
          _chips([
            for (final c in everydayCats)
              FilterChip(
                avatar: KeyIcon(c.iconKey, color: Color(c.colorValue)),
                label: Text(c.name),
                selected: _categoryIds.contains(c.id),
                onSelected: (v) => setState(
                  () => v ? _categoryIds.add(c.id) : _categoryIds.remove(c.id),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          _chips([
            for (final c in ownCats)
              Chip(
                avatar: KeyIcon(c.iconKey, color: Color(c.colorValue)),
                label: Text(c.name),
                onDeleted: () => ref.read(dbProvider).archiveCategory(c.id),
              ),
            for (final (i, c) in _newCategories.indexed)
              Chip(
                avatar: KeyIcon(c.iconKey, color: Color(_colorValue)),
                label: Text(c.name),
                onDeleted: () => setState(() => _newCategories.removeAt(i)),
              ),
            ActionChip(
              avatar: const AppIcon(Icons.add_rounded, size: 18),
              label: const Text('New category for this mode'),
              onPressed: _addCategory,
            ),
          ]),
          modeSectionLabel(theme, 'AUTO-TAGS'),
          hint('Put on everything added while it is ON — removable each time.'),
          _chips([
            for (final t in [...ownTags, ...everydayTags])
              FilterChip(
                label: Text(t.name),
                selected: _tagIds.contains(t.id),
                onSelected: (v) => setState(
                  () => v ? _tagIds.add(t.id) : _tagIds.remove(t.id),
                ),
              ),
            for (final (i, t) in _newTags.indexed)
              FilterChip(
                label: Text(t.name),
                selected: t.auto,
                onSelected: (v) =>
                    setState(() => _newTags[i] = (name: t.name, auto: v)),
                onDeleted: () => setState(() => _newTags.removeAt(i)),
              ),
            ActionChip(
              avatar: const AppIcon(Icons.add_rounded, size: 18),
              label: const Text('New tag for this mode'),
              onPressed: _addTag,
            ),
          ]),

          // ── Focus ─────────────────────────────────────────────────────
          modeSectionLabel(theme, 'WHILE IT IS ON'),
          hint('The two tabs beside ➕, and the modules in More.'),
          Row(
            children: [
              Expanded(
                child: _slotField(
                  'Left tab',
                  _slotLeft,
                  (v) => setState(() {
                    _slotLeft = v;
                    if (v == null) {
                      _slotRight = null;
                    } else {
                      _slotRight ??= v == 'persons'
                          ? 'transactions'
                          : 'persons';
                      if (_slotRight == v) _slotRight = null;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _slotField(
                  'Right tab',
                  _slotRight,
                  (v) => setState(() {
                    _slotRight = v;
                    if (v == null) {
                      _slotLeft = null;
                    } else {
                      _slotLeft ??= v == 'transactions'
                          ? 'persons'
                          : 'transactions';
                      if (_slotLeft == v) _slotLeft = null;
                    }
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _chips([
            for (final m in ModeModule.all)
              FilterChip(
                avatar: AppIcon(m.icon, size: 18),
                label: Text(m.label),
                selected: _modules.contains(m.key),
                onSelected: (v) => setState(
                  () => v ? _modules.add(m.key) : _modules.remove(m.key),
                ),
              ),
          ]),
          if (_modules.isEmpty) hint('Nothing ticked shows every module.'),

          // ── Group ─────────────────────────────────────────────────────
          if (groups.isNotEmpty) ...[
            modeSectionLabel(theme, 'GROUP'),
            hint(
              "A linked group's expenses always join this mode, and its "
              'members are the people above.',
            ),
            DropdownButtonFormField<int?>(
              initialValue: groups.any((g) => g.id == _groupId)
                  ? _groupId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Linked group'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final g in groups)
                  DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: _linkGroup,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isNew ? 'Create mode' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _chips(List<Widget> children) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);

  Widget _slotField(
    String label,
    String? value,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: null, child: Text('Everyday')),
      for (final e in modeNavSlotChoices.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: onChanged,
  );
}

/// A planned cost while the editor holds it; [id] null = not saved yet.
class _PlannedDraft {
  const _PlannedDraft({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.paid,
  });

  final int? id;
  final String name;
  final Money amount;
  final int? categoryId;
  final bool paid;
}
