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
    _modules = preset.modules.isEmpty ? {...ModeModule.keys} : preset.modules;
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
      _modules = modeModuleKeys(mode);
      _accountIds = accounts;
      _categoryIds = cats;
      _tagIds = tags;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
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
        );
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
      final autoTags = <int>{..._tagIds};
      for (final t in _newTags) {
        final tagId = await db.addModeTag(
          modeId: id,
          name: t.name,
          colorValue: _colorValue,
        );
        if (t.auto) autoTags.add(tagId);
      }
      if (autoTags.length != _tagIds.length) {
        final mode = (await db.modeById(id))!;
        await db.updateMode(
          id,
          name: mode.name,
          iconKey: mode.iconKey,
          colorValue: mode.colorValue,
          startDate: mode.startDate,
          endDate: mode.endDate,
          budget: mode.budget,
          currencyCode: mode.currencyCode,
          groupId: mode.groupId,
          navSlots: mode.navSlots,
          modules: mode.modules,
          accountIds: _accountIds,
          categoryIds: _categoryIds,
          tagIds: autoTags,
        );
      }
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
    final accounts = [
      for (final a in ref.watch(accountsProvider).valueOrNull ?? const [])
        if (a.type != AccountType.goal && a.type != AccountType.loan) a,
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
          modeSectionLabel(theme, 'PAYS WITH'),
          hint('Only these accounts are offered while it is ON. None = any.'),
          _chips([
            for (final a in accounts)
              FilterChip(
                label: Text(a.name),
                selected: _accountIds.contains(a.id),
                onSelected: (v) => setState(
                  () => v ? _accountIds.add(a.id) : _accountIds.remove(a.id),
                ),
              ),
          ]),
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
            hint("A linked group's expenses always join this mode."),
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
              onChanged: (v) => setState(() => _groupId = v),
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
