import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/language_pack.dart';
import '../../core/l10n/pack_store.dart';
import '../../core/platform/platform_features.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/open_link.dart';
import '../../data/providers.dart';

/// `Settings.languageCode`: a language picked by hand, or null to follow
/// the phone (GitHub #191).
final languageChoiceProvider = Provider<String?>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.languageCode;
});

/// Settings → Language (GitHub #191, #202). "Phone's language" follows the
/// phone — and is what a new install starts on — or pick any language
/// XPENC has; the whole app switches at once, no restart.
///
/// Each language is listed in its own script first, so someone who can't
/// read the current one still finds theirs. Below the list, a language
/// pack (from xpenc.in, or made by anyone) adds a language XPENC doesn't
/// ship, or updates the wording of one it does.
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// The language showing now picked up a change to its own pack: load it
  /// again and redraw everything.
  Future<void> _reloadIfShowing(String code) async {
    if (L10n.code != code) return;
    await L10n.load(code);
    WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllWidgets());
  }

  Future<void> _import() async {
    final FilePickerResult? picked;
    try {
      // No extension filter: some Android file managers grey out `.json`
      // under one. Decoding is the real check.
      picked = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      _say(tr("Couldn't open a file: {0}", [e]));
      return;
    }
    if (picked == null) return; // cancelled
    final bytes = picked.files.singleOrNull?.bytes;
    if (bytes == null) {
      _say(tr("Couldn't read that file."));
      return;
    }
    final LanguagePack pack;
    try {
      pack = LanguagePack.decode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException catch (e) {
      _say(e.message);
      return;
    }
    if (!mounted) return;

    final replacing = L10n.packFor(pack.code) != null;
    final builtIn = L10n.isBuiltIn(pack.code);
    final use = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${pack.nativeName} · ${pack.englishName}'),
        content: Text(
          [
            tr('{0} translated strings.', [pack.strings.length]),
            if (pack.dropped > 0)
              tr('{0} were left out because they would break the text.', [
                pack.dropped,
              ]),
            if (builtIn)
              tr(
                'Its wording replaces the built-in translation where they differ.',
              ),
            if (replacing) tr('It replaces the pack you imported before.'),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Just add it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Use it now'),
          ),
        ],
      ),
    );
    if (use == null) return;

    try {
      await LanguagePackStore.install(pack);
    } catch (e) {
      _say(tr("Couldn't save the language pack: {0}", [e]));
      return;
    }
    if (use) {
      await ref.read(dbProvider).setLanguageCode(pack.code);
    }
    await _reloadIfShowing(pack.code);
    if (mounted) setState(() {});
  }

  Future<void> _remove(AppLanguage language) async {
    final builtIn = L10n.isBuiltIn(language.code);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          builtIn
              ? tr('Remove the {0} pack?', [language.nativeName])
              : tr('Remove {0}?', [language.nativeName]),
        ),
        content: Text(
          builtIn
              ? tr('XPENC goes back to its built-in translation.')
              : tr(
                  'If it is the language showing, XPENC switches to your '
                  "phone's language. You can import the pack again any time.",
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LanguagePackStore.remove(language.code);
    if (!builtIn && ref.read(languageChoiceProvider) == language.code) {
      await ref.read(dbProvider).setLanguageCode(null);
    }
    await _reloadIfShowing(language.code);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final saved = ref.watch(languageChoiceProvider);
    final followsPhone = appLanguageFor(saved) == null;
    final phone = appLanguageFor(L10n.systemCode)!;
    final db = ref.read(dbProvider);

    Widget tile({
      required String title,
      required String? subtitle,
      required bool selected,
      required String? code,
      AppLanguage? removable,
      Key? key,
    }) {
      return AppListTile(
        key: key,
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) AppIcon(Icons.check_rounded, color: cs.primary),
            if (removable != null)
              IconButton(
                tooltip: tr('Remove pack'),
                icon: const AppIcon(Icons.delete_outline_rounded),
                onPressed: () => _remove(removable),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
        onTap: () => db.setLanguageCode(code),
      );
    }

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Language')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          AppCard(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: tile(
              key: const Key('language-system'),
              title: tr("Phone's language"),
              subtitle: phone.code == 'en'
                  ? tr("English — XPENC doesn't have your phone's language yet")
                  : '${phone.nativeName} · ${phone.englishName}',
              selected: followsPhone,
              code: null,
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final l in L10n.languages)
                  tile(
                    key: Key('language-${l.code}'),
                    title: l.nativeName,
                    subtitle: [
                      if (l.nativeName != l.englishName) l.englishName,
                      if (L10n.packFor(l.code) != null)
                        L10n.isBuiltIn(l.code)
                            ? tr('updated by a pack')
                            : tr('imported pack'),
                    ].join(' · ').nullIfEmpty,
                    selected: !followsPhone && saved == l.code,
                    code: l.code,
                    removable: L10n.packFor(l.code) == null ? null : l,
                  ),
              ],
            ),
          ),
          if (LanguagePackStore.supported) ...[
            const SizedBox(height: 16),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // xpenc.in/languages: download a pack, open it with
                  // XPENC, and it becomes the app's language (see
                  // language_pack_intake.dart).
                  AppListTile(
                    key: const Key('language-more'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const AppIcon(Icons.public_rounded),
                    title: const Tr('More languages'),
                    subtitle: Text(
                      tr('Download a language pack from {0}', ['xpenc.in']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: AppIcon(
                      Icons.open_in_new_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () => openLink(context, AppInfo.languagesUrl),
                  ),
                  AppListTile(
                    key: const Key('language-import'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const AppIcon(Icons.file_open_outlined),
                    title: const Tr('Import language pack'),
                    subtitle: Tr(
                      'A pack file already on this device',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    onTap: _import,
                  ),
                ],
              ),
            ),
            if (PlatformFeatures.shareIntake) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tr(
                  'Downloaded a pack? Open it and choose XPENC — the app '
                  'switches to that language straight away.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tr(
              'Translations are built into the app and work offline. Spot '
              'a wrong word? Tell us on GitHub and it gets fixed in the next '
              'update. PDFs and spreadsheets you export stay in English.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
