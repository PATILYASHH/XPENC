import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/outgoing_file.dart';
import '../../core/security/nct.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'share_cards.dart';
import 'share_models.dart';

/// Every Share — a transaction, a person, a group, a mode — lands here: what
/// will go, previewed; an Image ⇄ PDF slider that opens on whichever was
/// sent last; the period and the card's look; a scan-to-pay QR when
/// something's owed; and where it goes — straight into WhatsApp or
/// Messages, or the system share sheet ("More").
///
/// The image is captured at 3× (a 1080 px wide PNG) from the very preview
/// on screen.
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({
    required this.title,
    required this.fileStem,
    required this.subject,
    required this.image,
    required this.pdf,
    this.message,
    this.periods = const [],
    this.payments = const [],
    this.paymentsHint,
    this.recipientPhone,
    this.secure = false,
    super.key,
  });

  final String title;

  /// The file's name, without extension.
  final String fileStem;
  final String subject;

  /// The card for the chosen look and period, with the QR when it's on.
  final Widget Function(ShareCardTone tone, SharePeriod period, PaymentQr? qr)
  image;

  /// The PDF for the chosen period, with the QR when it's on.
  final Future<Uint8List> Function(SharePeriod period, PaymentQr? qr) pdf;

  /// The message that goes with the file. Defaults to [subject].
  final String Function(PaymentQr? qr)? message;

  /// Offered as choices when there's more than one, plus a custom range;
  /// the first is the default. Empty = no period ([SharePeriod.allTime]).
  final List<SharePeriod> periods;

  /// Scan-to-pay codes to offer, the first preselected — see
  /// [PaymentQr.optionsFor].
  final List<PaymentQr> payments;

  /// In place of the QR switch, when one could be offered but isn't set up.
  final String? paymentsHint;

  /// Their phone: WhatsApp and Messages open their chat with it.
  final String? recipientPhone;

  /// Keeps captures blocked while it's open — an NCT transaction (GitHub
  /// #143) is only ever on screen in the clear on a secure window.
  final bool secure;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

/// Which button is sending — its spinner, everything else disabled.
enum _Sending { whatsapp, messages, more }

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _boundary = GlobalKey();
  late ShareFormat _format;
  var _tone = ShareCardTone.dark;
  late SharePeriod _period;

  /// The custom range, once picked — it keeps its chip.
  SharePeriod? _custom;
  late bool _withQr = widget.payments.isNotEmpty;
  var _qrIndex = 0;
  Set<ShareApp> _apps = const {};
  _Sending? _sending;

  @override
  void initState() {
    super.initState();
    _format = ref.read(shareFormatProvider);
    _period = widget.periods.isEmpty
        ? SharePeriod.allTime
        : widget.periods.first;
    OutgoingFile.availableApps().then((apps) {
      if (mounted) setState(() => _apps = apps);
    });
  }

  PaymentQr? get _qr =>
      _withQr && widget.payments.isNotEmpty ? widget.payments[_qrIndex] : null;

  bool get _isImage => _format == ShareFormat.image;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          _custom?.range ??
          DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (picked == null || !mounted) return;
    setState(() => _period = _custom = SharePeriod.custom(picked));
  }

  Future<OutgoingFile> _file(PaymentQr? qr) async {
    if (!_isImage) {
      return OutgoingFile(
        name: '${widget.fileStem}.pdf',
        bytes: await widget.pdf(_period, qr),
        mimeType: 'application/pdf',
      );
    }
    // The frame showing the current choice has to be painted first.
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return OutgoingFile(
      name: '${widget.fileStem}.png',
      bytes: png!.buffer.asUint8List(),
      mimeType: 'image/png',
    );
  }

  Future<void> _send(_Sending via) async {
    final messenger = ScaffoldMessenger.of(context);
    final what = _isImage ? 'image' : 'PDF';
    final qr = _qr;
    final text = widget.message?.call(qr) ?? widget.subject;
    final app = switch (via) {
      _Sending.whatsapp => ShareApp.whatsapp,
      _Sending.messages => ShareApp.messages,
      _Sending.more => null,
    };
    setState(() => _sending = via);
    try {
      final file = await _file(qr);
      _remember();
      if (app == null) {
        await file.deliver(subject: widget.subject, text: text);
      } else {
        final result = await file.sendTo(
          app,
          text: text,
          whatsappJid: whatsappJid(
            widget.recipientPhone,
            currencyCode: ref.read(currencyProvider).code,
          ),
          phone: widget.recipientPhone,
        );
        switch (result) {
          case ShareAppResult.sent:
            break;
          case ShareAppResult.textOnly:
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    "Messages can't attach a $what, so only the text went. "
                    'Use More to send the file.',
                  ),
                ),
              );
          case ShareAppResult.failed:
            // The app went away, or wouldn't take it: the share sheet
            // still gets it anywhere.
            await file.deliver(subject: widget.subject, text: text);
        }
      }
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't create the $what: $e")),
        );
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  /// The next Share opens on what was just sent.
  void _remember() {
    if (ref.read(shareFormatProvider) == _format) return;
    ref.read(dbProvider).setShareFormat(_format).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    return Scaffold(
      appBar: AppTopBar(title: Text(widget.title)),
      body: SecureWhile(
        active: widget.secure,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isImage
                        ? _ImagePreview(
                            key: const ValueKey(ShareFormat.image),
                            boundary: _boundary,
                            child: widget.image(_tone, _period, qr),
                          )
                        : _PdfPreview(
                            key: const ValueKey(ShareFormat.pdf),
                            title: widget.subject,
                            fileName: '${widget.fileStem}.pdf',
                            lines: [
                              if (widget.periods.isNotEmpty) _period.label,
                              'Structured and printable, with every detail',
                              if (qr != null) 'Scan-to-pay QR · ${qr.method}',
                            ],
                          ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShareFormatSlider(
                            value: _format,
                            onChanged: (f) => setState(() => _format = f),
                          ),
                        ),
                        if (_isImage) ...[
                          const SizedBox(width: 12),
                          SegmentedButton<ShareCardTone>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ShareCardTone.dark,
                                tooltip: 'Dark card',
                                icon: AppIcon(Icons.dark_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ShareCardTone.light,
                                tooltip: 'Light card',
                                icon: AppIcon(Icons.light_mode_outlined),
                              ),
                            ],
                            selected: {_tone},
                            onSelectionChanged: (s) =>
                                setState(() => _tone = s.first),
                          ),
                        ],
                      ],
                    ),
                    if (widget.periods.length > 1) ...[
                      const SizedBox(height: 10),
                      _periodChips(),
                    ],
                    if (widget.payments.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _qrSwitch(),
                    ] else if (widget.paymentsHint != null) ...[
                      const SizedBox(height: 10),
                      _hint(widget.paymentsHint!),
                    ],
                    const SizedBox(height: 12),
                    _sendRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChips() {
    final custom = _custom;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in widget.periods)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.label),
                selected: identical(_period, p),
                showCheckmark: false,
                onSelected: (_) => setState(() => _period = p),
              ),
            ),
          ChoiceChip(
            avatar: const AppIcon(Icons.date_range_outlined, size: 18),
            label: Text(custom?.label ?? 'Custom range'),
            selected: custom != null && identical(_period, custom),
            showCheckmark: false,
            onSelected: (_) => _pickCustom(),
          ),
        ],
      ),
    );
  }

  Widget _qrSwitch() {
    final qr = _qr ?? widget.payments.first;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const AppIcon(Icons.qr_code_2_rounded),
          title: const Text('Payment QR'),
          subtitle: Text(
            '${qr.method} · ${qr.id}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value: _withQr,
          onChanged: (v) => setState(() => _withQr = v),
        ),
        if (_withQr && widget.payments.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < widget.payments.length; i++)
                ChoiceChip(
                  label: Text(widget.payments[i].method),
                  selected: i == _qrIndex,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _qrIndex = i),
                ),
            ],
          ),
      ],
    );
  }

  Widget _hint(String text) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        AppIcon(Icons.qr_code_2_rounded, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }

  Widget _sendRow() {
    final busy = _sending != null;
    if (_apps.isEmpty) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: busy ? null : () => _send(_Sending.more),
        icon: busy ? const _Spinner() : const AppIcon(Icons.ios_share_rounded),
        label: Text(_isImage ? 'Share image' : 'Share PDF'),
      );
    }
    Widget target(_Sending via, IconData icon, String label) => Expanded(
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: busy ? null : () => _send(via),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: _sending == via ? const _Spinner() : AppIcon(icon),
            ),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    final targets = [
      if (_apps.contains(ShareApp.whatsapp))
        target(_Sending.whatsapp, Icons.chat_outlined, 'WhatsApp'),
      if (_apps.contains(ShareApp.messages))
        target(_Sending.messages, Icons.sms_outlined, 'Messages'),
      target(_Sending.more, Icons.more_horiz_rounded, 'More'),
    ];
    return Row(
      children: [
        for (var i = 0; i < targets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          targets[i],
        ],
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

/// The card as it will be sent, scaled down to fit a narrow screen — the
/// capture is always taken at the card's own 360-wide size.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.boundary, required this.child, super.key});

  final GlobalKey boundary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: RepaintBoundary(key: boundary, child: child),
        ),
      ),
    );
  }
}

/// What the PDF will be — a PDF can't be drawn here, so a sheet of paper
/// with its name and what's in it.
class _PdfPreview extends StatelessWidget {
  const _PdfPreview({
    required this.title,
    required this.fileName,
    required this.lines,
    super.key,
  });

  final String title;
  final String fileName;
  final List<String> lines;

  static const _ink = Color(0xFF0E0E10);
  static const _muted = Color(0xFF6B6B76);
  static const _bar = Color(0xFFEDEDF1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bar(double width) => Container(
      width: width,
      height: 6,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Container(
      width: 260,
      // A4's proportions.
      height: 260 * 1.414,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              const AppIcon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: _muted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          bar(180),
          bar(150),
          bar(196),
          bar(120),
          const Spacer(),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: AppIcon(
                      Icons.check_rounded,
                      size: 14,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(color: _ink, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// Image ⇄ PDF as one sliding switch: a thumb glides to the side picked —
/// tap a side, or drag across.
class ShareFormatSlider extends StatelessWidget {
  const ShareFormatSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ShareFormat value;
  final ValueChanged<ShareFormat> onChanged;

  static const _options = [
    (ShareFormat.image, Icons.image_outlined, 'Image'),
    (ShareFormat.pdf, Icons.picture_as_pdf_outlined, 'PDF'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        void dragTo(double dx) {
          final picked = dx < box.maxWidth / 2
              ? ShareFormat.image
              : ShareFormat.pdf;
          if (picked != value) onChanged(picked);
        }

        return GestureDetector(
          onHorizontalDragUpdate: (d) => dragTo(d.localPosition.dx),
          child: Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: value == ShareFormat.image
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.onSurface,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (format, icon, label) in _options)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: format == value,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onChanged(format),
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(
                                end: format == value
                                    ? cs.surface
                                    : cs.onSurfaceVariant,
                              ),
                              duration: const Duration(milliseconds: 200),
                              // Shrinks rather than clips at a large
                              // text size.
                              builder: (context, color, _) => FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(icon, size: 18, color: color),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: color,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
