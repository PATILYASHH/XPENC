// Wraps XPENC's user-facing English strings for translation (GitHub #191).
//
//   dart run tool/l10n/wrap_strings.dart            # dry run: report only
//   dart run tool/l10n/wrap_strings.dart --write    # rewrite lib/
//
// Text('Save')            -> Tr('Save')                (stays const-able)
// tooltip: 'Edit account' -> tooltip: tr('Edit account')
// 'Paid $n of $m'         -> tr('Paid {0} of {1}', [n, m])
//
// A `const` that a tr() call would break is dropped from the nearest
// expression that declares it. Strings in places that must stay constant —
// a top-level/static constant, a default parameter value, an enum's
// arguments — are left as they are and listed in tool/l10n/const_data.txt
// so their display sites can translate them instead. Every string wrapped
// or listed goes into tool/l10n/catalog.json, the list translators work
// from.
//
// Parse-only (no resolution), so it works without a build: decisions are
// made from the syntax around each string, never its type.
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Files whose strings are data or protocol, not interface text — or, for
/// PDFs and CSVs, must stay English (the PDF fonts have no Indian scripts,
/// and CSV headers are read back by importers).
const _skipFiles = <String>[
  'lib/core/l10n/',
  'lib/core/currency.dart',
  'lib/core/countries.dart',
  'lib/core/world_tax.dart',
  'lib/core/connector/',
  'lib/core/platform/',
  'lib/core/payments/',
  'lib/core/home_widget/',
  'lib/core/theme/',
  'lib/data/built_in_category_templates.dart',
  'lib/features/data_export/report_pdf.dart',
  'lib/features/data_export/statement_pdf.dart',
  'lib/features/data_export/csv_import.dart',
  'lib/features/share/share_pdfs.dart',
  'lib/features/share/pdf_kit.dart',
  'lib/features/message_capture/',
  'lib/core/routing/app_router.dart',
];

/// In these, only an error message thrown to the person is interface text;
/// everything else (seed rows, SQL, column names) is data.
const _errorsOnlyFiles = <String>['lib/data/'];

/// Calls whose string arguments are never shown as interface text.
const _rejectCallees = <String>{
  'Key', 'ValueKey', 'ObjectKey', 'GlobalKey', 'PageStorageKey',
  'UniqueKey', 'LabeledGlobalKey', 'GlobalObjectKey',
  'debugPrint', 'print', 'log', 'assert', 'RegExp', 'DateFormat',
  'NumberFormat', 'Uri', 'parse', 'tryParse', 'launchUrl',
  'launchUrlString', 'canLaunchUrl', 'MethodChannel', 'EventChannel',
  'BasicMessageChannel', 'OptionalMethodChannel', 'customStatement',
  'customSelect', 'customUpdate', 'customInsert', 'Variable', 'Constant',
  'startsWith', 'endsWith', 'contains', 'split', 'replaceAll',
  'replaceFirst', 'replaceAllMapped', 'indexOf', 'lastIndexOf',
  'padLeft', 'padRight', 'Locale', 'AssetImage', 'asset', 'loadString',
  'load', 'File', 'Directory', 'Link', 'join', 'joinAll', 'withDefault',
  'jsonEncode', 'jsonDecode', 'fromEnvironment', 'getString', 'setString',
  'getBool', 'setBool', 'getInt', 'setInt', 'invokeMethod',
  'invokeListMethod', 'invokeMapMethod', 'FontFeature', 'push', 'go',
  'pushReplacement', 'pushNamed', 'goNamed', 'pushZoom', 'replace',
  'StateError', 'UnimplementedError', 'UnsupportedError',
  'AssertionError', 'ArgumentError.value', 'ArgumentError.notNull',
  'checkNotNull', 'Intl', 'DateTime', 'Duration', 'Color', 'fromHex',
  'currencyForCode', 'appLanguageFor', 'tr', 'Tr', 'utf8', 'encode',
  'shareFileStem', // a-z/0-9 slug: translated text would vanish
  'decode', 'add', 'putIfAbsent', 'remove', 'containsKey', 'where',
  'firstWhere', 'any', 'every', 'equals', 'like', 'isIn', 'isNotIn',
  'matchesRegex', 'textEnum', 'compareTo', 'Platform', 'Hero',
  'MimeType', 'XFile', 'ShareParams', 'FileType', 'setMockMethodCallHandler',
  'AndroidNotificationChannel', 'AndroidNotificationDetails',
  'RawAutocomplete', 'Semantics.fromProperties', 'TextInputType',
  'FilteringTextInputFormatter', 'allow', 'deny', 'withName',
  'ColorFilter', 'fromAsset', 'svg', 'SvgPicture', 'precacheImage',
  'NetworkImage', 'Image.network', 'Image.asset', 'Image.file',
  'GoRoute', 'ShellRoute', 'StatefulShellRoute', 'StatefulShellBranch',
  'Tween', 'Interval', 'getApplicationDocumentsDirectory', 'Uint8List',
  'Pattern', 'sqlite', 'select', 'update', 'into', 'delete', 'from',
  'readAs', 'read', 'write', 'writeAsString', 'writeAsBytes', 'rename',
  'copy', 'createSync', 'existsSync', 'ofType', 'cast',
};

/// Named arguments that carry identifiers, paths or data, never interface
/// text.
const _rejectNamed = <String>{
  'key', 'debugLabel', 'fontFamily', 'package', 'restorationId', 'heroTag',
  'name', 'path', 'routeName', 'initialLocation', 'semanticsIdentifier',
  'mimeType', 'fileName', 'filename', 'channelId', 'channelName',
  'groupKey', 'payload', 'tag', 'id', 'url', 'scheme', 'host', 'query',
  'fragment', 'extension', 'locale', 'pattern', 'symbol', 'code',
  'currencyCode', 'iconKey', 'sql', 'table', 'column', 'storageKey',
  'uri', 'note', 'payee', 'icon', 'emoji', 'glyph', 'prefix', 'separator',
  'json', 'type', 'kind', 'value', 'format', 'mode', 'route', 'location',
  'action', 'category', 'source', 'sender', 'merchant', 'bankName',
  'last4', 'vpa', 'upiId', 'pn', 'pa', 'cu', 'am', 'tn', 'sharedRef',
  'remoteEntryId', 'hash', 'salt', 'secret', 'token', 'nonce',
  'firstName', 'lastName', 'title_', 'cacheKey', 'assetName', 'family',
  'packageName', 'appId', 'applicationId', 'androidPackageName',
  'iOSBundleId', 'subject_', 'accountName', 'personName', 'groupName',
  'fallback', 'shortName', 'nativeName', 'englishName',
};

/// Named arguments that always hold interface text — even a single word.
const _uiNamed = <String>{
  'labelText', 'hintText', 'helperText', 'errorText', 'counterText',
  'prefixText', 'suffixText', 'tooltip', 'semanticLabel', 'semanticsLabel',
  'title', 'subtitle', 'label', 'message', 'content', 'description',
  'hint', 'confirmLabel', 'cancelLabel', 'actionLabel', 'buttonLabel',
  'emptyText', 'emptyMessage', 'heading', 'header', 'caption', 'body',
  'text', 'placeholder', 'question', 'answer', 'explanation', 'detail',
  'details', 'helpText', 'confirmText', 'cancelText', 'fieldLabelText',
  'fieldHintText', 'errorFormatText', 'errorInvalidText', 'barrierLabel',
  'semanticsValue', 'confirm', 'cancel', 'okLabel', 'yesLabel', 'noLabel',
  'primaryLabel', 'secondaryLabel', 'trailingText', 'leadingText',
  'subject', 'summary', 'headline', 'bodyText', 'titleText', 'actionText',
  'unit', 'unitLabel', 'noun', 'emptyLabel', 'sectionTitle', 'info',
  'warning', 'errorMessage', 'successMessage', 'undoLabel', 'reason',
  'shortLabel', 'longLabel', 'caption2', 'tagline', 'intro', 'outro',
  'whatsNew', 'what', 'why', 'how', 'where', 'help', 'tip', 'lead',
  'deleteLabel', 'saveLabel', 'doneLabel', 'nextLabel', 'backLabel',
};

/// Strings that look like interface text but must stay exactly as they are
/// — an id, a file name, a debug string, or a label kept in English on
/// purpose (Settings' "Language" row, so it can always be found).
const _never = <String>{
  'Asia/Kolkata',
  'Money({0} paise)',
  '{0}{1}{2}XPENCEBACKUP.json',
  'Language',
  '{0} · Language',
};

/// Text-showing constructors whose first argument is the text.
const _textCtors = <String>{'Text', 'SelectableText'};

/// Getter/function names whose returned strings are interface labels.
final _labelFnName = RegExp(
  r'(label|title|name|text|caption|heading|hint|description|subtitle|'
  r'message|word|display|noun|verb|tooltip|summary|explain|phrase|'
  r'headline|blurb|copy|helper|status|reason|prompt|question|answer)',
  caseSensitive: false,
);

class Edit {
  Edit(this.offset, this.end, this.text);
  final int offset;
  final int end;
  final String text;
}

class Finding {
  Finding(this.file, this.line, this.key, this.kind);
  final String file;
  final int line;
  final String key;
  final String kind; // wrapped | text | const-data | skipped-nested
}

final findings = <Finding>[];

/// `path:line` locations to wrap whatever the classifier thinks — for text
/// it turns away on purpose (a label returned in a record, a `?? 'Other'`
/// fallback, a `'$n word'` count). From tool/l10n/force.txt.
final _forced = <String>{};
final catalog = <String, String>{}; // key -> first location

void main(List<String> args) {
  final write = args.contains('--write');
  final forceFile = File('tool/l10n/force.txt');
  if (forceFile.existsSync()) {
    for (final l in forceFile.readAsLinesSync()) {
      final t = l.trim();
      if (t.isNotEmpty && !t.startsWith('#')) _forced.add(t);
    }
  }
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var changedFiles = 0;
  var totalEdits = 0;
  for (final file in files) {
    final rel = file.path.replaceAll('\\', '/');
    if (_skipFiles.any(rel.startsWith)) continue;
    var content = file.readAsStringSync();
    var fileEdits = 0;
    // Nested strings (inside another wrapped string's ${...}) are reached on
    // a later pass, once the outer one has become tr('…', [args]).
    for (var pass = 0; pass < 4; pass++) {
      final edits = _process(rel, content);
      if (edits.isEmpty) break;
      content = _apply(content, edits);
      fileEdits += edits.length;
    }
    if (fileEdits > 0) {
      changedFiles++;
      totalEdits += fileEdits;
      if (write) {
        content = _ensureImport(rel, content);
        file.writeAsStringSync(content);
      }
    }
  }

  final kinds = <String, int>{};
  for (final f in findings) {
    kinds[f.kind] = (kinds[f.kind] ?? 0) + 1;
  }
  print('files changed: $changedFiles, edits: $totalEdits');
  print('findings: $kinds');
  print('catalog: ${catalog.length} unique strings, '
      '${catalog.keys.fold<int>(0, (s, k) => s + k.length)} chars');

  Directory('tool/l10n').createSync(recursive: true);
  final constData = findings.where((f) => f.kind == 'const-data');
  File('tool/l10n/const_data.txt').writeAsStringSync(
    constData.map((f) => '${f.file}:${f.line}\t${f.key}').join('\n'),
  );
  File('tool/l10n/findings.txt').writeAsStringSync(
    findings.map((f) => '${f.kind}\t${f.file}:${f.line}\t${f.key}').join('\n'),
  );
  // The catalogue itself is built by extract_catalog.dart.
}

String _apply(String content, List<Edit> edits) {
  // Deduplicate (two strings under one const share its removal) and apply
  // back to front so offsets stay valid.
  final seen = <String>{};
  final unique = <Edit>[];
  for (final e in edits) {
    if (seen.add('${e.offset}:${e.end}:${e.text}')) unique.add(e);
  }
  unique.sort((a, b) => b.offset.compareTo(a.offset));
  var out = content;
  var lastStart = out.length + 1;
  for (final e in unique) {
    if (e.end > lastStart) {
      throw StateError('overlapping edits at ${e.offset}');
    }
    out = out.replaceRange(e.offset, e.end, e.text);
    lastStart = e.offset;
  }
  return out;
}

String _ensureImport(String rel, String content) {
  if (content.contains("core/l10n/l10n.dart'")) return content;
  final depth = rel.split('/').length - 2; // lib/a/b.dart -> 1
  final prefix = depth == 0 ? '' : '../' * depth;
  final import = "import '${prefix}core/l10n/l10n.dart';";
  final nl = content.contains('\r\n') ? '\r\n' : '\n';
  // After the last import directive.
  final matches = RegExp(r"^import [^;]+;", multiLine: true)
      .allMatches(content)
      .toList();
  if (matches.isEmpty) return '$import$nl$content';
  final last = matches.last;
  return content.replaceRange(last.end, last.end, '$nl$import');
}

List<Edit> _process(String rel, String content) {
  final result = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _Visitor(rel, content, result.lineInfo.getLocation);
  result.unit.accept(visitor);
  return visitor.edits;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.rel, this.content, this.locate);

  final String rel;
  final String content;
  final dynamic Function(int) locate;
  final edits = <Edit>[];
  final _claimed = <AstNode>[];

  int _line(int offset) => (locate(offset) as dynamic).lineNumber as int;

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _consider(node);
    // Its parts are handled as one string.
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is AdjacentStrings) return;
    _consider(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (node.parent is AdjacentStrings) {
      super.visitStringInterpolation(node);
      return;
    }
    _consider(node);
    super.visitStringInterpolation(node);
  }

  bool _insideClaimed(AstNode node) {
    for (final c in _claimed) {
      if (node.offset >= c.offset && node.end <= c.end && node != c) {
        return true;
      }
    }
    return false;
  }

  /// The first argument of tr()/plural()/Tr() — wrapping it again (a forced
  /// line on a re-run) would nest tr(tr(…)).
  bool _alreadyTranslated(StringLiteral node) {
    final list = node.parent;
    if (list is! ArgumentList) return false;
    final call = list.parent;
    final name = switch (call) {
      MethodInvocation(:final methodName) => methodName.name,
      InstanceCreationExpression(:final constructorName) =>
        constructorName.type.name.lexeme,
      _ => null,
    };
    return name == 'tr' || name == 'Tr' || name == 'plural';
  }

  void _consider(StringLiteral node) {
    if (_insideClaimed(node)) {
      return; // next pass
    }
    if (_alreadyTranslated(node)) return;
    final built = _build(node);
    if (built == null) return;
    final (key, literalSource, args) = built;
    final line = _line(node.offset);
    final forced = _forced.contains('$rel:$line') &&
        !_never.contains(key) &&
        !_hardReject(node) &&
        RegExp('[A-Za-z]{2}').hasMatch(key.replaceAll(RegExp(r'\{\d+\}'), ''));
    final verdict = forced ? 'forced' : _classify(node, key);
    if (verdict == null) return;

    catalog.putIfAbsent(key, () => '$rel:$line');

    final blocker = _constBlocker(node);
    if (blocker != null) {
      findings.add(Finding(rel, line, key, 'const-data'));
      return;
    }

    _claimed.add(node);
    final textCtor = _textCtorOf(node);
    if (textCtor != null && args.isEmpty) {
      // Text('Save') -> Tr('Save'): stays const.
      edits.add(Edit(textCtor.offset, textCtor.end, 'Tr'));
      findings.add(Finding(rel, line, key, 'text'));
      return;
    }
    final call = args.isEmpty
        ? 'tr($literalSource)'
        : 'tr($literalSource, [${args.join(', ')}])';
    edits.add(Edit(node.offset, node.end, call));
    for (final c in _constsToDrop(node)) {
      edits.add(c);
    }
    findings.add(Finding(rel, line, key, 'wrapped'));
  }

  /// The key (runtime text, `{i}` for each interpolation), the literal's
  /// source with each interpolation replaced by `{i}`, and the expression
  /// sources in order. Null for raw strings.
  (String, String, List<String>)? _build(StringLiteral node) {
    final parts = <StringLiteral>[
      if (node is AdjacentStrings) ...node.strings else node,
    ];
    final key = StringBuffer();
    final args = <String>[];
    final exprs = <InterpolationExpression>[];
    for (final p in parts) {
      if (p is SimpleStringLiteral) {
        if (p.isRaw) return null;
        key.write(p.value);
      } else if (p is StringInterpolation) {
        if (p.isRaw) return null;
        for (final e in p.elements) {
          if (e is InterpolationString) {
            key.write(e.value);
          } else if (e is InterpolationExpression) {
            key.write('{${args.length}}');
            args.add(content.substring(e.expression.offset, e.expression.end));
            exprs.add(e);
          }
        }
      } else {
        return null;
      }
    }
    var source = content.substring(node.offset, node.end);
    for (var i = exprs.length - 1; i >= 0; i--) {
      final e = exprs[i];
      source = source.replaceRange(
        e.offset - node.offset,
        e.end - node.offset,
        '{$i}',
      );
    }
    return (key.toString(), source, args);
  }

  /// Null to leave [node] alone; otherwise why it counts as interface text.
  String? _classify(StringLiteral node, String key) {
    if (_never.contains(key)) return null;
    final letters = key.replaceAll(RegExp(r'\{\d+\}'), '');
    if (!RegExp('[A-Za-z]{2}').hasMatch(letters)) return null;
    final trimmed = key.trim();
    if (trimmed.contains('://') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('package:') ||
        trimmed.startsWith('assets/') ||
        trimmed.startsWith('dart:')) {
      return null;
    }
    if (RegExp(r'^[a-z0-9_.\-/:@#?=&%+{}]+$').hasMatch(trimmed)) return null;
    if (RegExp(r'^[A-Z0-9_]{2,}$').hasMatch(trimmed) && trimmed != 'OK') {
      return null;
    }
    if (RegExp(r'^(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|PRAGMA|DROP|'
            r'WITH|BEGIN|COMMIT)\b')
        .hasMatch(trimmed)) {
      return null;
    }
    // camelCase / snake_case identifiers.
    if (RegExp(r'^[a-z]+[A-Z][A-Za-z0-9]*$').hasMatch(trimmed)) return null;
    if (trimmed.contains('_') && !trimmed.contains(' ')) return null;

    final ctx = _context(node);
    if (ctx == 'reject') return null;

    final errorsOnly = _errorsOnlyFiles.any(rel.startsWith);
    if (errorsOnly && ctx != 'error') return null;

    if (ctx == 'ui' || ctx == 'error' || ctx == 'label-fn') return ctx;

    // Elsewhere, only something that reads like a phrase: two or more
    // words, starting with a capital (or a placeholder), or ending like a
    // sentence.
    final words = RegExp('[A-Za-z]+').allMatches(letters).length;
    final startsLikeText = RegExp(r'^(\{\d+\}|[A-Z"“‘(…])').hasMatch(trimmed);
    final endsLikeSentence = RegExp(r'[.?!…:]$').hasMatch(trimmed);
    if (words >= 2 && (startsLikeText || endsLikeSentence)) return 'phrase';
    // Lowercase or digit-led words with spaces between — "1 transaction
    // detected", "they owe you". Identifiers never have spaces; SQL and
    // the like were turned away above.
    if (words >= 2 &&
        trimmed.contains(' ') &&
        RegExp(r"^[a-z0-9{]").hasMatch(trimmed) &&
        !RegExp(r'[=<>;\[\]|]').hasMatch(trimmed) &&
        ctx != 'other') {
      return 'phrase-lc';
    }
    // A single capitalised word passed straight to a widget or helper.
    if (words == 1 && RegExp(r'^[A-Z][a-z]+$').hasMatch(trimmed) &&
        ctx == 'call-arg') {
      return 'word';
    }
    return null;
  }

  /// For a forced location: only arguments that are never words — a date
  /// pattern, a key, a regex, a URI, a channel or SQL.
  bool _hardReject(StringLiteral node) {
    const hard = {
      'DateFormat', 'NumberFormat', 'RegExp', 'Key', 'ValueKey', 'ObjectKey',
      'GlobalKey', 'Uri', 'parse', 'launchUrl', 'MethodChannel',
      'customStatement', 'customSelect', 'debugPrint', 'print', 'Locale',
    };
    AstNode? n = node.parent;
    if (n is NamedExpression) n = n.parent;
    if (n is ArgumentList) {
      final callee = _calleeName(n.parent);
      if (callee != null &&
          (hard.contains(callee) || hard.contains(callee.split('.').last))) {
        return true;
      }
    }
    return false;
  }

  /// 'reject', 'ui', 'error', 'label-fn', 'call-arg' or 'other'.
  String _context(StringLiteral node) {
    AstNode child = node;
    AstNode? parent = node.parent;
    // Look through parentheses, conditionals and `??`, which only choose
    // between texts.
    while (parent is ParenthesizedExpression ||
        parent is ConditionalExpression ||
        (parent is BinaryExpression &&
            parent.operator.lexeme == '??') ||
        parent is ListLiteral && false) {
      if (parent is ConditionalExpression && parent.condition == child) {
        return 'reject';
      }
      child = parent!;
      parent = parent.parent;
    }
    if (parent == null) return 'other';

    if (parent is Directive || parent is Annotation) return 'reject';
    if (parent is MapLiteralEntry && parent.key == child) return 'reject';
    if (parent is IndexExpression) return 'reject';
    if (parent is SwitchCase || parent is ConstantPattern) return 'reject';
    if (parent is BinaryExpression) {
      final op = parent.operator.lexeme;
      if (op == '==' || op == '!=') return 'reject';
      if (op == '+') return 'other';
    }
    if (parent is AssignmentExpression) {
      final target = content.substring(
        parent.leftHandSide.offset,
        parent.leftHandSide.end,
      );
      if (_dataName(target)) return 'reject';
      return 'other';
    }
    if (parent is VariableDeclaration) {
      if (_dataName(parent.name.lexeme)) return 'reject';
      return 'other';
    }
    if (parent is ExpressionFunctionBody || parent is ReturnStatement ||
        parent is SwitchExpressionCase) {
      final fn = _enclosingFunctionName(parent);
      if (fn != null && _labelFnName.hasMatch(fn)) return 'label-fn';
      if (parent is SwitchExpressionCase) {
        // `x => 'Label'` arms are almost always labels.
        return 'label-fn';
      }
      return 'other';
    }

    NamedExpression? named;
    var argHolder = parent;
    if (parent is NamedExpression) {
      named = parent;
      argHolder = parent.parent!;
    }
    if (argHolder is ArgumentList) {
      final call = argHolder.parent;
      final callee = _calleeName(call);
      if (callee != null) {
        if (_rejectCallees.contains(callee) ||
            _rejectCallees.contains(callee.split('.').last)) {
          return 'reject';
        }
        if (callee == 'ArgumentError' ||
            callee == 'Exception' ||
            callee == 'FormatException' ||
            callee.endsWith('Exception')) {
          return 'error';
        }
      }
      if (named != null) {
        final n = named.name.label.name;
        if (_rejectNamed.contains(n)) return 'reject';
        if (_uiNamed.contains(n)) return 'ui';
        return 'call-arg';
      }
      if (callee != null &&
          (_textCtors.contains(callee) ||
              callee == 'Tooltip' ||
              callee == 'TextSpan')) {
        return 'ui';
      }
      return 'call-arg';
    }
    if (parent is ThrowExpression) return 'error';
    if (parent is ListLiteral || parent is SetOrMapLiteral) return 'other';
    if (parent is MapLiteralEntry) return 'other';
    return 'other';
  }

  bool _dataName(String name) => RegExp(
    // Whole words only — `contextLine` and `text` are not file `ext`s.
    r'\b(key|id|path|url|uri|route|channel|table|column|sql|pattern|format|'
    r'prefix|suffix|scheme|mime|ext|font|asset|file|code|tag|token|secret|'
    r'salt|hash|host|query|separator|regex|glyph|emoji|icon)\b',
    caseSensitive: false,
  ).hasMatch(name.replaceAllMapped(
    RegExp('([a-z])([A-Z])'),
    (m) => '${m[1]} ${m[2]}',
  ));

  String? _enclosingFunctionName(AstNode from) {
    AstNode? n = from;
    while (n != null) {
      if (n is MethodDeclaration) return n.name.lexeme;
      if (n is FunctionDeclaration) return n.name.lexeme;
      if (n is FunctionExpression && n.parent is! FunctionDeclaration) {
        return null;
      }
      n = n.parent;
    }
    return null;
  }

  String? _calleeName(AstNode? call) {
    if (call is MethodInvocation) {
      final target = call.target;
      if (target is SimpleIdentifier &&
          RegExp('^[A-Z]').hasMatch(target.name)) {
        return '${target.name}.${call.methodName.name}';
      }
      return call.methodName.name;
    }
    if (call is InstanceCreationExpression) {
      final type = call.constructorName.type.name.lexeme;
      final named = call.constructorName.name?.name;
      return named == null ? type : '$type.$named';
    }
    if (call is SuperConstructorInvocation) return 'super';
    if (call is FunctionExpressionInvocation) {
      final f = call.function;
      if (f is SimpleIdentifier) return f.name;
    }
    return null;
  }

  /// The `Text` name token when [node] is the first argument of a plain
  /// `Text(...)` (not `Text.rich`).
  dynamic _textCtorOf(StringLiteral node) {
    final list = node.parent;
    if (list is! ArgumentList || list.arguments.first != node) return null;
    final call = list.parent;
    if (call is MethodInvocation &&
        call.target == null &&
        call.methodName.name == 'Text') {
      return call.methodName;
    }
    if (call is InstanceCreationExpression &&
        call.constructorName.name == null &&
        call.constructorName.type.name.lexeme == 'Text' &&
        call.constructorName.type.importPrefix == null) {
      return call.constructorName.type.name;
    }
    return null;
  }

  /// Why a tr() call can't go here (a constant that must stay constant), or
  /// null when it can.
  String? _constBlocker(AstNode node) {
    AstNode? n = node.parent;
    while (n != null) {
      if (n is FunctionBody) return null; // runtime code from here up
      if (n is DefaultFormalParameter) return 'default-value';
      if (n is EnumConstantDeclaration) return 'enum-arg';
      if (n is Annotation) return 'annotation';
      if (n is ConstructorFieldInitializer) {
        final ctor = n.parent;
        if (ctor is ConstructorDeclaration && ctor.constKeyword != null) {
          return 'const-ctor-init';
        }
      }
      if (n is VariableDeclarationList) {
        final decl = n.parent;
        final isTop = decl is TopLevelVariableDeclaration;
        final isStatic = decl is FieldDeclaration && decl.isStatic;
        final isConstClassField = decl is FieldDeclaration &&
            !decl.isStatic &&
            _classHasConstCtor(decl);
        if (isTop || isStatic || isConstClassField) return 'static-data';
        return null;
      }
      n = n.parent;
    }
    return null;
  }

  bool _classHasConstCtor(FieldDeclaration decl) {
    final cls = decl.parent;
    if (cls is! BlockClassBody) return false;
    for (final m in cls.members) {
      if (m is ConstructorDeclaration && m.constKeyword != null) return true;
    }
    return false;
  }

  /// Edits dropping every explicit `const` between [node] and its function
  /// body — a local `const x = …` becomes `final`.
  List<Edit> _constsToDrop(AstNode node) {
    final out = <Edit>[];
    AstNode? n = node.parent;
    while (n != null && n is! FunctionBody) {
      Object? kw;
      if (n is InstanceCreationExpression) {
        kw = n.keyword;
      } else if (n is TypedLiteral) {
        kw = n.constKeyword;
      } else if (n is VariableDeclarationList) {
        final k = n.keyword;
        if (k != null && k.lexeme == 'const') {
          out.add(Edit(k.offset, k.end, 'final'));
        }
      } else if (n is RecordLiteral) {
        kw = n.constKeyword;
      }
      if (kw != null) {
        final t = kw as dynamic;
        if (t.lexeme == 'const') {
          var end = t.end as int;
          while (end < content.length &&
              (content[end] == ' ' || content[end] == '\t')) {
            end++;
          }
          out.add(Edit(t.offset as int, end, ''));
        }
      }
      n = n.parent;
    }
    return out;
  }
}
