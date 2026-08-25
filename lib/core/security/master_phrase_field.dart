import 'package:flutter/material.dart';

import 'recovery_words.dart';

/// Free-text entry for the master recovery phrase — used both embedded in
/// the lock screen (no `Scaffold` of its own) and wrapped in a route for the
/// Settings "turn off" flow. Splits on whitespace and lowercases, so casing
/// and extra spaces don't matter (see [RecoveryWords.normalize]).
class MasterPhraseField extends StatefulWidget {
  const MasterPhraseField({
    required this.onSubmit,
    this.submitLabel = 'Unlock',
    this.error,
    this.busy = false,
    super.key,
  });

  final ValueChanged<List<String>> onSubmit;
  final String submitLabel;

  /// An error from the caller (e.g. "Wrong phrase") — shown alongside any
  /// local word-count validation error.
  final String? error;
  final bool busy;

  @override
  State<MasterPhraseField> createState() => _MasterPhraseFieldState();
}

class _MasterPhraseFieldState extends State<MasterPhraseField> {
  final _controller = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final words = RecoveryWords.normalize(_controller.text);
    if (words.length != RecoveryWords.wordCount) {
      setState(
        () => _localError =
            'Enter all ${RecoveryWords.wordCount} words, separated by spaces',
      );
      return;
    }
    setState(() => _localError = null);
    widget.onSubmit(words);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error ?? _localError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          enabled: !widget.busy,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          minLines: 2,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'word1 word2 word3 …',
            errorText: error,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.busy ? null : _submit,
            child: widget.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
