import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/security/paste_code_key.dart';
import '../../core/security/pin_pad.dart';
import '../../core/security/totp.dart';
import '../../data/providers.dart';
import 'lock_screen_keypad.dart';

enum _Step { scan, confirm }

const _codeLength = 6;

/// Generates a fresh TOTP secret, shows the QR code an authenticator app
/// scans to add it, then requires one correct 6-digit code before it's
/// saved — proof the app was actually set up, the same "confirm before
/// committing" shape as [MasterPhraseSetupScreen]'s tap-back-in-order step.
/// GitHub #104.
class TotpSetupScreen extends ConsumerStatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  ConsumerState<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends ConsumerState<TotpSetupScreen> {
  _Step _step = _Step.scan;
  late String _secret;
  String _code = '';
  bool _error = false;
  bool _saving = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _secret = Totp.generateSecret();
  }

  void _goToConfirm() => setState(() => _step = _Step.confirm);

  void _onDigit(String d) {
    if (_saving || _code.length >= _codeLength) return;
    setState(() {
      _error = false;
      _code += d;
    });
    if (_code.length == _codeLength) _submit();
  }

  void _onBackspace() {
    if (_saving || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  /// The keypad's "paste" key (GitHub #111) — fills in whatever digits the
  /// clipboard holds (from the authenticator app's own "copy code" action,
  /// say) and submits immediately once there are enough of them, exactly as
  /// if they'd been typed one by one.
  void _onPaste(String digits) {
    if (_saving) return;
    setState(() {
      _error = false;
      _code = digits.length > _codeLength
          ? digits.substring(0, _codeLength)
          : digits;
    });
    if (_code.length == _codeLength) _submit();
  }

  Future<void> _submit() async {
    // Verified locally against the not-yet-saved secret — nothing is
    // persisted until the code proves the authenticator app actually has it.
    if (!Totp.verify(_secret, _code)) {
      setState(() {
        _error = true;
        _code = '';
        _attempt++;
      });
      return;
    }
    setState(() => _saving = true);
    await ref.read(dbProvider).setupTotp(_secret);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Authenticator app set up')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == _Step.scan ? 'Authenticator app' : 'Enter the code',
        ),
      ),
      body: SafeArea(
        child: _step == _Step.scan
            ? _buildScan(context)
            : _buildConfirm(context),
      ),
    );
  }

  Widget _buildScan(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Scan this QR code with Google Authenticator, Authy, or any '
          'compatible app.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: Totp.provisioningUri(_secret),
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Can't scan? Enter this code manually:",
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          _secret,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 20),
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
                  'If you lose this device or uninstall your authenticator '
                  'app, a master recovery phrase is the only way back in — '
                  'set one up too if you haven’t. Without one, losing the '
                  'authenticator locks you out until you restore a backup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _goToConfirm,
          child: const Text("I've added it to my app"),
        ),
      ],
    );
  }

  Widget _buildConfirm(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const Spacer(flex: 2),
        Text(
          'Enter the 6-digit code',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (_error)
          Text(
            'Wrong code — try again',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        const SizedBox(height: 18),
        PinDots(entered: _code.length, length: _codeLength, error: _error),
        const Spacer(flex: 3),
        if (_saving)
          const CircularProgressIndicator()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LockScreenKeypad(
              style: ref.watch(lockScreenStyleProvider),
              attempt: _attempt,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              extraKey: PasteCodeKey(onCode: _onPaste),
            ),
          ),
        const Spacer(),
      ],
    );
  }
}
