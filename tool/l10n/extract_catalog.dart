// Builds tool/l10n/catalog.json — every English string the app looks up —
// and checks each language table in assets/l10n/ against it (GitHub #191).
//
//   dart run tool/l10n/extract_catalog.dart          # write catalog + report
//   dart run tool/l10n/extract_catalog.dart --check  # report only; exit 1 on
//                                                    # a placeholder problem
//
// The catalogue is the first argument of every tr('…') and Tr('…') in lib/,
// plus tool/l10n/data_keys.txt: text held in constants (nav labels, the
// guide, What's New…) that is translated where it's shown, by tr(field).
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

final _keys = <String, String>{}; // key -> first location
final _problems = <String>[];

void main(List<String> args) {
  final check = args.contains('--check');
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final rel = f.path.replaceAll('\\', '/');
    final result = parseString(
      content: f.readAsStringSync(),
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    result.unit.accept(_Collector(rel, result.lineInfo));
  }
  final dataKeys = File('tool/l10n/data_keys.txt');
  if (dataKeys.existsSync()) {
    for (final line in dataKeys.readAsLinesSync()) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      _keys.putIfAbsent(line.replaceAll(r'\n', '\n'), () => 'data_keys.txt');
    }
  }

  final keys = _keys.keys.toList();
  if (!check) {
    File('tool/l10n/catalog.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(keys),
    );
  }
  print('catalog: ${keys.length} strings, '
      '${keys.fold<int>(0, (s, k) => s + k.length)} chars');

  // Each language table: coverage, and placeholders that don't match.
  final placeholder = RegExp(r'\{(\d+)\}');
  final dir = Directory('assets/l10n');
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final table = (jsonDecode(f.readAsStringSync()) as Map)
          .cast<String, String>();
      final missing = keys.where((k) => !table.containsKey(k)).length;
      final stale = table.keys.where((k) => !_keys.containsKey(k)).length;
      for (final e in table.entries) {
        final allowed = placeholder.allMatches(e.key).map((m) => m[0]).toSet();
        for (final m in placeholder.allMatches(e.value)) {
          if (!allowed.contains(m[0])) {
            _problems.add('${f.path}: "${e.key}" -> "${e.value}" adds ${m[0]}');
          }
        }
      }
      print('${f.uri.pathSegments.last}: ${table.length} entries, '
          '$missing missing, $stale stale');
    }
  }
  for (final p in _problems) {
    print('PROBLEM $p');
  }
  if (check && _problems.isNotEmpty) exit(1);
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.rel, this.lineInfo);
  final String rel;
  final dynamic lineInfo;

  void _take(ArgumentList list, int offset) {
    if (list.arguments.isEmpty) return;
    final first = list.arguments.first;
    if (first is StringInterpolation) {
      _problems.add('$rel: tr()/Tr() of an interpolated string — use {0}');
      return;
    }
    if (first is SingleStringLiteral || first is AdjacentStrings) {
      final value = (first as StringLiteral).stringValue;
      if (value == null) return;
      final line = lineInfo.getLocation(offset).lineNumber;
      _keys.putIfAbsent(value, () => '$rel:$line');
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (node.target == null && (name == 'tr' || name == 'Tr')) {
      _take(node.argumentList, node.offset);
    }
    // plural(count, '1 entry', '{0} entries') — both forms are keys; so
    // are the last two arguments of the share cards' _MoreLine.
    final args = node.argumentList.arguments;
    if (node.target == null && name == '_MoreLine' && args.length == 4) {
      for (final a in args.skip(2)) {
        if (a is SimpleStringLiteral) {
          _keys.putIfAbsent(a.value, () => '$rel (plural)');
        }
      }
    }
    if (node.target == null &&
        name == 'plural' &&
        node.argumentList.arguments.length == 3) {
      for (final a in node.argumentList.arguments.skip(1)) {
        // Adjacent strings too: a long sentence split over lines.
        final value = a is StringLiteral ? a.stringValue : null;
        if (value != null) {
          _keys.putIfAbsent(value, () => '$rel (plural)');
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'Tr' &&
        node.constructorName.name == null) {
      _take(node.argumentList, node.offset);
    }
    super.visitInstanceCreationExpression(node);
  }
}
