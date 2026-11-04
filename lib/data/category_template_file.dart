import 'dart:convert';

import 'database.dart' show CategoryTemplateItemRow;
import 'tables.dart' show CategoryKind;

/// A category template as a file to share (GitHub #187): the shape of a
/// category set — names, money in or out, colours, icons, and which sit
/// under which — and nothing else. No ids, no budgets, no transactions, so
/// it's safe to post anywhere, and it can be applied on a phone that has
/// never seen these categories.
///
/// ```json
/// {
///   "format": "xpenc-category-template",
///   "version": 1,
///   "name": "50/30/20",
///   "description": "Needs and wants…",
///   "income": [{ "name": "Salary", "icon": "salary", "color": "#16A34A" }],
///   "expense": [
///     { "name": "Needs", "icon": "house", "color": "#2563EB",
///       "children": [{ "name": "Rent", "icon": "rent", "color": "#DC2626" }] }
///   ]
/// }
/// ```
class CategoryTemplateFile {
  const CategoryTemplateFile({
    required this.name,
    required this.income,
    required this.expense,
    this.description,
  });

  static const format = 'xpenc-category-template';
  static const version = 1;

  /// Plenty for any real structure; a file past it isn't one.
  static const maxCategories = 400;

  final String name;
  final String? description;
  final List<TemplateCategory> income;
  final List<TemplateCategory> expense;

  int get categoryCount =>
      [...income, ...expense].fold(0, (n, c) => n + 1 + c.children.length);

  /// A saved template's rows, as a file.
  factory CategoryTemplateFile.fromItems(
    String name,
    List<CategoryTemplateItemRow> items,
  ) {
    final sorted = [...items]..sort((a, b) => a.sortOrder - b.sortOrder);
    List<TemplateCategory> top(CategoryKind kind) => [
      for (final p in sorted)
        if (p.parentItemId == null && p.kind == kind)
          TemplateCategory(
            name: p.name,
            colorValue: p.colorValue,
            iconKey: p.iconKey,
            children: [
              for (final c in sorted)
                if (c.parentItemId == p.id)
                  TemplateCategory(
                    name: c.name,
                    colorValue: c.colorValue,
                    iconKey: c.iconKey,
                  ),
            ],
          ),
    ];
    return CategoryTemplateFile(
      name: name,
      income: top(CategoryKind.income),
      expense: top(CategoryKind.expense),
    );
  }

  /// A file name that says what it is, safe on every file system.
  String get fileName {
    final safe = name.replaceAll(RegExp(r'[^\w\- ]+'), ' ').trim();
    return '${safe.isEmpty ? 'Categories' : safe} - XPENC categories.json';
  }

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': format,
    'version': version,
    'name': name,
    if (description != null) 'description': description,
    'income': [for (final c in income) c._toJson()],
    'expense': [for (final c in expense) c._toJson()],
  });

  /// Reads a template file. Throws a [FormatException] whose message can be
  /// shown as it is when [text] isn't one.
  static CategoryTemplateFile decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException("That isn't an XPENC category template.");
    }
    if (json is! Map || json['format'] != format) {
      throw const FormatException("That isn't an XPENC category template.");
    }
    final v = json['version'];
    if (v is! int || v > version) {
      throw const FormatException(
        'That template was made by a newer XPENC — update the app to use it.',
      );
    }
    final name = _string(json['name'], max: 60) ?? 'Shared template';
    final description = _string(json['description'], max: 400);
    List<TemplateCategory> list(Object? raw, {required bool top}) {
      if (raw == null) return const [];
      if (raw is! List) {
        throw const FormatException('That template is damaged.');
      }
      return [for (final c in raw) TemplateCategory._fromJson(c, top: top)];
    }

    final file = CategoryTemplateFile(
      name: name,
      description: description,
      income: list(json['income'], top: true),
      expense: list(json['expense'], top: true),
    );
    if (file.categoryCount == 0) {
      throw const FormatException('That template has no categories.');
    }
    if (file.categoryCount > maxCategories) {
      throw const FormatException('That template has too many categories.');
    }
    return file;
  }
}

/// One category in a [CategoryTemplateFile], with its subcategories.
class TemplateCategory {
  const TemplateCategory({
    required this.name,
    required this.colorValue,
    required this.iconKey,
    this.children = const [],
  });

  final String name;
  final int colorValue;

  /// An `AppIcons` key, or `emoji:<glyph>`.
  final String iconKey;

  /// Only a top-level category has any: categories nest two levels deep.
  final List<TemplateCategory> children;

  Map<String, Object?> _toJson() => {
    'name': name,
    'icon': iconKey,
    'color':
        '#${(colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    if (children.isNotEmpty)
      'children': [for (final c in children) c._toJson()],
  };

  static TemplateCategory _fromJson(Object? json, {required bool top}) {
    if (json is! Map) throw const FormatException('That template is damaged.');
    final name = _string(json['name'], max: 40);
    if (name == null) {
      throw const FormatException(
        'Every category in a template needs a name of up to 40 letters.',
      );
    }
    final rawChildren = json['children'];
    if (rawChildren != null && !top) {
      throw const FormatException(
        'Categories nest two levels deep — that template goes deeper.',
      );
    }
    if (rawChildren != null && rawChildren is! List) {
      throw const FormatException('That template is damaged.');
    }
    return TemplateCategory(
      name: name,
      // Unknown or missing icons and colours fall back rather than reject:
      // a template from a newer build may know icons this one doesn't.
      iconKey: _string(json['icon'], max: 40) ?? 'other',
      colorValue: _color(json['color']) ?? 0xFF64748B,
      children: [
        for (final c in (rawChildren as List?) ?? const [])
          TemplateCategory._fromJson(c, top: false),
      ],
    );
  }
}

String? _string(Object? v, {required int max}) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty || t.length > max ? null : t;
}

int? _color(Object? v) {
  if (v is! String) return null;
  final hex = v.startsWith('#') ? v.substring(1) : v;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex, radix: 16);
}
