import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/recovery_words.dart';
import '../../data/providers.dart';

enum _Step { reveal, confirm }

/// Generates a 10-word master recovery phrase and has the user tap it back
/// in order before it's saved — proof they actually copied it down, the
/// same shape as a crypto wallet's seed-phrase backup flow. The words are
/// never stored: only a salted hash (see `AppDatabase.setMasterPhrase`), so
/// once this screen closes there is no way to see them again. GitHub #74.
class MasterPhraseSetupScreen extends ConsumerStatefulWidget {
  const MasterPhraseSetupScreen({super.key});

  @override
  ConsumerState<MasterPhraseSetupScreen> createState() =>
      _MasterPhraseSetupScreenState();
}

class _MasterPhraseSetupScreenState
    extends ConsumerState<MasterPhraseSetupScreen> {
  _Step _step = _Step.reveal;
  late List<String> _words;
  late List<String> _shuffled;
  final Set<int> _usedChips = {};
  final List<String> _picked = [];
  bool _mismatch = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _words = RecoveryWords.generate();
      _shuffled = List<String>.of(_words)..shuffle();
      _usedChips.clear();
      _picked.clear();
      _mismatch = false;
    });
  }

  void _goToConfirm() {
    setState(() {
      _shuffled = List<String>.of(_words)..shuffle();
      _usedChips.clear();
      _picked.clear();
      _mismatch = false;
      _step = _Step.confirm;
    });
  }

  Future<void> _onChipTap(int chipIndex) async {
    if (_usedChips.contains(chipIndex) || _saving) return;
    final word = _shuffled[chipIndex];
    if (word != _words[_picked.length]) {
      setState(() => _mismatch = true);
      return;
    }
    setState(() {
      _mismatch = false;
      _picked.add(word);
      _usedChips.add(chipIndex);
    });
    if (_picked.length == _words.length) await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(dbProvider).setMasterPhrase(_words);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Master recovery phrase set')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == _Step.reveal ? 'Recovery phrase' : 'Confirm phrase',
        ),
      ),
      body: SafeArea(
        child: _step == _Step.reveal ? _buildReveal(context) : _buildConfirm(context),
      ),
    );
  }

  Widget _buildReveal(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Write these ${_words.length} words down, in order, and keep them '
          'somewhere safe. If XPENC ever locks you out after too many wrong '
          'PIN attempts, this phrase is the only way back in.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "It can't be changed and it isn't stored anywhere "
                  'recoverable — not in a backup, not by XPENC. Lose it '
                  "along with your PIN and there's no way back into your "
                  'data on this device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < _words.length; i++)
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${i + 1}. ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: _words[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _regenerate,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Generate different words'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _goToConfirm,
          child: const Text("I've written it down"),
        ),
      ],
    );
  }

  Widget _buildConfirm(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap the words in the order you wrote them down.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _words.length; i++)
                Chip(
                  label: Text(i < _picked.length ? _picked[i] : '${i + 1}'),
                  backgroundColor: i < _picked.length
                      ? cs.primaryContainer
                      : null,
                ),
            ],
          ),
          if (_mismatch) ...[
            const SizedBox(height: 8),
            Text(
              "That's not the next word — try again",
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _shuffled.length; i++)
                ActionChip(
                  label: Text(_shuffled[i]),
                  onPressed: _usedChips.contains(i)
                      ? null
                      : () => _onChipTap(i),
                ),
            ],
          ),
          if (_saving) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
