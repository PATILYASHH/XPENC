import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

enum _IdKind { upiId, phone }

/// "Pay without internet" (Beta) — a merchant/anyone UPI payment over NPCI's
/// *99# USSD service, for when there's no data connection.
///
/// No app, this one included, can read or answer the *99# menu itself —
/// that screen belongs to the phone's own dialer, not any third-party app
/// (see the info sheet in Settings → Payment Support → UPI). So this screen
/// only does what's actually possible: collect who's being paid, copy it to
/// the clipboard, open the dialer pre-filled with *99#, and afterward let
/// the user log what they paid as a normal transaction — it never touches
/// the Persons ledger, since most of the time this is a merchant, not
/// someone to track a debt with.
class UssdPayScreen extends StatefulWidget {
  const UssdPayScreen({super.key});

  @override
  State<UssdPayScreen> createState() => _UssdPayScreenState();
}

class _UssdPayScreenState extends State<UssdPayScreen> {
  _IdKind _idKind = _IdKind.upiId;
  final _idController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String get _id => _idController.text.trim();

  Future<void> _copyId() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_id.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _idKind == _IdKind.upiId
                  ? 'Enter a UPI ID first.'
                  : 'Enter a phone number first.',
            ),
          ),
        );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _id));
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied')));
  }

  /// `tel:*99%23` — the `#` must stay percent-encoded or it's parsed as a
  /// URI fragment separator, not part of the number. Opens the dialer with
  /// the code ready to call (`ACTION_DIAL`); it never places the call
  /// itself, so no `CALL_PHONE` permission is needed.
  Future<void> _dial() async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('tel:*99%23'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Couldn't open the dialer")));
  }

  void _logPayment() {
    if (_id.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _idKind == _IdKind.upiId
                  ? 'Enter who you paid first.'
                  : 'Enter their phone number first.',
            ),
          ),
        );
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    final query = {
      'type': 'expense',
      'payee': _id,
      'note': 'Paid via *99# (offline UPI)',
      if (amount != null && amount > 0) 'amount': amount.toStringAsFixed(2),
    };
    context.push(Uri(path: '/add', queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay without internet (Beta)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Who are you paying?',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<_IdKind>(
                segments: const [
                  ButtonSegment(value: _IdKind.upiId, label: Text('UPI ID')),
                  ButtonSegment(
                    value: _IdKind.phone,
                    label: Text('Phone number'),
                  ),
                ],
                selected: {_idKind},
                onSelectionChanged: (s) => setState(() {
                  _idKind = s.first;
                  _idController.clear();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idController,
                autocorrect: false,
                keyboardType: _idKind == _IdKind.phone
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _idKind == _IdKind.upiId
                      ? 'UPI ID'
                      : 'Phone number',
                  hintText: _idKind == _IdKind.upiId
                      ? 'e.g. shop@okhdfcbank'
                      : 'e.g. 98765 43210',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Optional — fills it in when you log this later',
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to pay',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Copy the ID below.\n'
                        '2. Dial *99# — your phone\'s own USSD menu takes '
                        'over from here (XPENC can\'t read or answer it).\n'
                        '3. Choose Send Money → paste the ID → enter the '
                        'amount → enter your UPI PIN.\n'
                        '4. Come back here and log what you paid.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyId,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _dial,
                      icon: const Icon(Icons.dialpad_rounded),
                      label: const Text('Dial *99#'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              FilledButton.tonal(
                onPressed: _logPayment,
                child: const Text('Log this payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
