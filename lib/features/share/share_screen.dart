import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/branding/brand_mark.dart';
import '../../core/money.dart';
import '../../core/platform/outgoing_file.dart';
import '../../core/security/nct.dart';
import '../../core/widgets/action_sheet.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'share_app_glyphs.dart';
import 'share_cards.dart';
import 'share_models.dart';

/// Every Share — a transaction, a person, a group, a mode — lands here. Top
/// to bottom: an Image ⇄ PDF slider (opening on whichever was sent last),
/// what will go, previewed, and a dock — the period, a scan-to-pay QR and
/// the card's look as one row of pills, then where it goes: straight into
/// up to [ShareTargets.maxPinned] apps of the user's choosing (WhatsApp and
/// Messages until they choose; long-press one to swap, move or drop it),
/// or the system share sheet ("More").
///
/// Switching Image ⇄ PDF moves nothing: the dock keeps every pill in its
/// place (the look pill only greys out for a PDF) and the app row is the
/// same in both.
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

  /// In place of the QR pill, when one could be offered but isn't set up.
  final String? paymentsHint;

  /// Their phone: WhatsApp and Messages open their chat with it.
  final String? recipientPhone;

  /// Keeps captures blocked while it's open — an NCT transaction (GitHub
  /// #143) is only ever on screen in the clear on a secure window.
  final bool secure;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

/// What the edit sheets answer with, besides the new row.
enum _PinEdit { reset }

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _boundary = GlobalKey();
  late ShareFormat _format;
  var _tone = ShareCardTone.dark;
  late SharePeriod _period;

  /// The custom range, once picked — it keeps its chip.
  SharePeriod? _custom;
  late bool _withQr = widget.payments.isNotEmpty;
  var _qrIndex = 0;

  /// The phone's share targets — null until they're in.
  ShareTargets? _targets;

  /// Which button is sending — a target's id, or [_more]: its spinner,
  /// everything else disabled.
  String? _sending;
  static const _more = '';

  @override
  void initState() {
    super.initState();
    _format = ref.read(shareFormatProvider);
    _period = widget.periods.isEmpty
        ? SharePeriod.allTime
        : widget.periods.first;
    if (OutgoingFile.canShareToApps) _loadTargets();
  }

  Future<void> _loadTargets() async {
    final targets = await OutgoingFile.shareTargets();
    if (mounted) setState(() => _targets = targets);
  }

  PaymentQr? get _qr =>
      _withQr && widget.payments.isNotEmpty ? widget.payments[_qrIndex] : null;

  bool get _isImage => _format == ShareFormat.image;

  String get _mimeType => _isImage ? 'image/png' : 'application/pdf';

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

  /// Straight into [target], or — null — the system share sheet.
  Future<void> _send(ShareTarget? target) async {
    final messenger = ScaffoldMessenger.of(context);
    final what = _isImage ? 'image' : 'PDF';
    final qr = _qr;
    final text = widget.message?.call(qr) ?? widget.subject;
    setState(() => _sending = target?.id ?? _more);
    try {
      final file = await _file(qr);
      _remember();
      if (target == null) {
        await file.deliver(subject: widget.subject, text: text);
      } else {
        final result = await file.sendTo(
          target,
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
                    "${target.label} can't attach a $what, so only the text "
                    'went. Use More to send the file.',
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

  /// A tap on an app that won't take what's chosen.
  void _cantTake(ShareTarget target) {
    final (what, other) = _isImage ? ('an image', 'PDF') : ('a PDF', 'Image');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "${target.label} doesn't take $what. Switch to $other, or use "
            'More.',
          ),
        ),
      );
  }

  /// Saves the row as [ids] — or, null, back to the default — on this phone.
  Future<void> _pin(List<String>? ids) async {
    final targets = _targets;
    if (targets == null) return;
    if (ids != null) setState(() => _targets = targets.withPinned(ids));
    await OutgoingFile.pinShareTargets(ids);
    if (ids == null) await _loadTargets();
  }

  Future<void> _applyEdit(Future<Object?> sheet) async {
    final picked = await sheet;
    if (!mounted) return;
    if (picked == _PinEdit.reset) {
      await _pin(null);
    } else if (picked is List<String>) {
      await _pin(picked);
    }
  }

  /// Long-press on the row's [index]th app: move it, drop it, or swap in
  /// another.
  void _editPinned(int index) {
    final targets = _targets;
    if (targets == null) return;
    final pinned = targets.pinned;
    final ids = [for (final t in pinned) t.id];
    final current = pinned[index];
    final others = targets.unpinned;
    List<String> moved(int to) => [...ids]
      ..removeAt(index)
      ..insert(to, current.id);
    final destructive = Theme.of(context).colorScheme.error;
    _applyEdit(
      showActionSheet<Object>(
        context: context,
        title: current.label,
        optionCount: others.length + 4,
        options: (sheet) => [
          if (index > 0)
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_left),
              title: const Text('Move left'),
              onTap: () => Navigator.pop(sheet, moved(index - 1)),
            ),
          if (index < ids.length - 1)
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_right),
              title: const Text('Move right'),
              onTap: () => Navigator.pop(sheet, moved(index + 1)),
            ),
          ListTile(
            leading: Icon(CupertinoIcons.minus_circle, color: destructive),
            title: Text(
              'Remove from Share',
              style: TextStyle(color: destructive),
            ),
            onTap: () => Navigator.pop(sheet, [...ids]..removeAt(index)),
          ),
          if (targets.customized) _resetTile(sheet),
          if (others.isNotEmpty) ...[
            const _SheetHeading('Replace with'),
            for (final t in others)
              _AppTile(
                target: t,
                onTap: () => Navigator.pop(sheet, [...ids]..[index] = t.id),
              ),
          ],
        ],
      ),
    );
  }

  /// "Add": one more app on the row.
  void _addPinned() {
    final targets = _targets;
    if (targets == null) return;
    final ids = [for (final t in targets.pinned) t.id];
    final others = targets.unpinned;
    _applyEdit(
      showActionSheet<Object>(
        context: context,
        title: 'Add to Share',
        optionCount: others.length + 2,
        options: (sheet) => [
          const _SheetNote(
            'Shown on every Share, up to ${ShareTargets.maxPinned}. '
            'Long-press one there to move, swap or remove it.',
          ),
          for (final t in others)
            _AppTile(
              target: t,
              onTap: () => Navigator.pop(sheet, [...ids, t.id]),
            ),
          if (targets.customized) _resetTile(sheet),
        ],
      ),
    );
  }

  Widget _resetTile(BuildContext sheet) => ListTile(
    leading: const Icon(CupertinoIcons.arrow_counterclockwise),
    title: const Text('Back to the default apps'),
    subtitle: const Text('WhatsApp and Messages'),
    onTap: () => Navigator.pop(sheet, _PinEdit.reset),
  );

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    return Scaffold(
      appBar: AppTopBar(title: Text(widget.title)),
      body: SecureWhile(
        active: widget.secure,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Center(
                child: ShareFormatSlider(
                  value: _format,
                  onChanged: (f) => setState(() => _format = f),
                ),
              ),
            ),
            Expanded(
              child: ShaderMask(
                // Fades out above the dock rather than stopping at an edge.
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0, 0.9, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    // Whatever fits sits in the middle of the stage, so the
                    // card and the page swap about the same centre.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, box.maxHeight - 60),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween(
                                    begin: 0.97,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: _isImage
                              ? _ImagePreview(
                                  key: const ValueKey(ShareFormat.image),
                                  boundary: _boundary,
                                  child: widget.image(_tone, _period, qr),
                                )
                              : _PdfPreview(
                                  key: const ValueKey(ShareFormat.pdf),
                                  title: widget.subject,
                                  period: widget.periods.isEmpty
                                      ? null
                                      : _period.label,
                                  qr: qr,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _dock(context),
          ],
        ),
      ),
    );
  }

  /// The period, the QR and the card's look as one row of pills, then where
  /// it goes. The same pills for Image and PDF — the look last, greyed out
  /// for a PDF — so switching moves nothing.
  Widget _dock(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final darkCard = _isImage && _tone == ShareCardTone.dark;
    final pills = [
      if (widget.periods.length > 1) _periodPill(),
      if (widget.payments.isNotEmpty) _qrPill(),
      _OptionPill(
        icon: darkCard ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
        label: darkCard ? 'Dark' : 'Light',
        tooltip: !_isImage
            ? 'A PDF is always light'
            : darkCard
            ? 'Light card'
            : 'Dark card',
        onTap: _isImage
            ? () => setState(
                () =>
                    _tone = darkCard ? ShareCardTone.light : ShareCardTone.dark,
              )
            : null,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pills.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < pills.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        pills[i],
                      ],
                    ],
                  ),
                ),
              if (widget.payments.isEmpty && widget.paymentsHint != null) ...[
                const SizedBox(height: 12),
                _hint(widget.paymentsHint!),
              ],
              SizedBox(height: pills.isEmpty ? 4 : 20),
              _sendRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodPill() {
    final custom = _custom;
    final options = [...widget.periods, ?custom];
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (final p in options)
          MenuItemButton(
            leadingIcon: _MenuCheck(identical(p, _period)),
            onPressed: () => setState(() => _period = p),
            child: Text(p.label),
          ),
        MenuItemButton(
          leadingIcon: const Icon(CupertinoIcons.calendar, size: 18),
          onPressed: _pickCustom,
          child: const Text('Custom range…'),
        ),
      ],
      builder: (context, controller, _) => _OptionPill(
        icon: CupertinoIcons.calendar,
        label: _period.label,
        chevron: true,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _qrPill() {
    final qr = _qr;
    final label = qr == null ? 'No QR' : '${qr.method} QR';
    if (widget.payments.length == 1) {
      return _OptionPill(
        icon: CupertinoIcons.qrcode,
        label: label,
        active: qr != null,
        tooltip: qr == null ? 'Add a scan-to-pay QR' : 'Remove the QR',
        onTap: () => setState(() => _withQr = !_withQr),
      );
    }
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        for (var i = 0; i < widget.payments.length; i++)
          MenuItemButton(
            leadingIcon: _MenuCheck(_withQr && i == _qrIndex),
            onPressed: () => setState(() {
              _withQr = true;
              _qrIndex = i;
            }),
            child: Text(
              '${widget.payments[i].method} · ${widget.payments[i].id}',
            ),
          ),
        MenuItemButton(
          leadingIcon: _MenuCheck(!_withQr),
          onPressed: () => setState(() => _withQr = false),
          child: const Text('No QR'),
        ),
      ],
      builder: (context, controller, _) => _OptionPill(
        icon: CupertinoIcons.qrcode,
        label: label,
        active: qr != null,
        chevron: true,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _hint(String text) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(CupertinoIcons.info_circle, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }

  /// The apps on the row, an "Add" while there's room, and More — the same
  /// for Image and PDF: an app that won't take the one chosen only dims.
  Widget _sendRow() {
    final busy = _sending != null;
    final targets = _targets;
    if (!OutgoingFile.canShareToApps ||
        (targets != null && targets.all.isEmpty)) {
      return _PrimaryShareButton(
        label: _isImage ? 'Share image' : 'Share PDF',
        busy: busy,
        onPressed: busy ? null : () => _send(null),
      );
    }
    final theme = Theme.of(context);
    final glow = theme.brightness == Brightness.light;
    final pinned = targets?.pinned ?? const <ShareTarget>[];
    final canAdd =
        targets != null &&
        pinned.length < ShareTargets.maxPinned &&
        targets.unpinned.isNotEmpty;
    final slots = pinned.length + (canAdd ? 1 : 0) + 1;
    return LayoutBuilder(
      builder: (context, box) {
        // Five to a row on a narrow phone still clear each other.
        final extent = (box.maxWidth / slots - 16).clamp(48.0, 60.0);
        Widget slot(Widget child) => Expanded(child: Center(child: child));
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, t) in pinned.indexed)
              slot(
                _ShareTarget(
                  key: ValueKey(t.id),
                  label: t.label,
                  extent: extent,
                  disc: _TargetDisc(t, extent: extent),
                  glow: glow ? _glowOf(t) : null,
                  busy: _sending == t.id,
                  enabled: !busy,
                  dimmed: !t.canSend(_mimeType),
                  onTap: () => t.canSend(_mimeType) ? _send(t) : _cantTake(t),
                  onLongPress: busy ? null : () => _editPinned(i),
                ),
              ),
            if (canAdd)
              slot(
                _ShareTarget(
                  label: 'Add',
                  extent: extent,
                  disc: _AddDisc(extent: extent),
                  enabled: !busy,
                  onTap: _addPinned,
                ),
              ),
            slot(
              _ShareTarget(
                label: 'More',
                extent: extent,
                disc: _MoreDisc(extent: extent),
                busy: _sending == _more,
                enabled: !busy,
                onTap: () => _send(null),
              ),
            ),
          ],
        );
        // Until the phone's apps are in, the row holds its place unseen.
        return AnimatedOpacity(
          opacity: targets == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: targets == null
              ? IgnorePointer(child: ExcludeSemantics(child: row))
              : row,
        );
      },
    );
  }
}

/// The light-theme glow under WhatsApp's and Messages' discs.
Color? _glowOf(ShareTarget t) => switch (t.kind) {
  ShareTargetKind.whatsapp => _whatsappGreen.last,
  ShareTargetKind.messages => _messagesBlue.last,
  ShareTargetKind.app => null,
};

const _whatsappGreen = [Color(0xFF5CF27F), Color(0xFF1EBE57)];
const _messagesBlue = [Color(0xFF5AA2FF), Color(0xFF1E6BF0)];

/// Black or white — whichever reads on [fill]. Glass's `surface` isn't
/// opaque, so it can't be the ink on an inverted pill.
Color _inkOn(Color fill) =>
    ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
    ? Colors.white
    : const Color(0xFF0E0E10);

class _MenuCheck extends StatelessWidget {
  const _MenuCheck(this.on);

  final bool on;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: on ? const Icon(CupertinoIcons.checkmark, size: 16) : null,
  );
}

/// One of the dock's options — the period, the QR, the card's look — as a
/// capsule. [active] inverts it, ink on paper: the QR that will go. No
/// [onTap] greys it out in place: an option the other format doesn't have.
class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.chevron = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool chevron;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fill = active ? cs.onSurface : cs.surfaceContainerHighest;
    final fg = active ? _inkOn(fill) : cs.onSurface;
    final pill = AnimatedOpacity(
      opacity: onTap == null ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 9, chevron ? 10 : 14, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(icon, key: ValueKey(icon), size: 16, color: fg),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (chevron) ...[
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 12,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}

/// A share target, share-sheet style: the app's disc, its name under it.
/// Presses in a touch; [dimmed] when it won't take what's chosen (a tap then
/// says why); [onLongPress] edits the row.
class _ShareTarget extends StatefulWidget {
  const _ShareTarget({
    required this.label,
    required this.disc,
    required this.onTap,
    required this.extent,
    this.onLongPress,
    this.busy = false,
    this.enabled = true,
    this.dimmed = false,
    this.glow,
    super.key,
  });

  final String label;
  final Widget disc;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double extent;
  final bool busy;
  final bool enabled;
  final bool dimmed;

  /// A coloured shadow, to lift a bright disc off a light page.
  final Color? glow;

  @override
  State<_ShareTarget> createState() => _ShareTargetState();
}

class _ShareTargetState extends State<_ShareTarget> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glow = widget.glow;
    final enabled = widget.enabled;
    final onLongPress = widget.onLongPress;
    final opacity = !enabled && !widget.busy
        ? 0.45
        : widget.dimmed
        ? 0.35
        : 1.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? widget.onTap : null,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : 'Change',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: enabled ? widget.onTap : null,
        onLongPress: onLongPress == null
            ? null
            : () {
                setState(() => _down = false);
                HapticFeedback.selectionClick();
                onLongPress();
              },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: opacity,
          child: AnimatedScale(
            scale: _down ? 0.92 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: widget.extent,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (glow != null)
                            BoxShadow(
                              color: glow.withValues(alpha: 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.disc,
                          if (widget.busy)
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0x66000000),
                              ),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A target's disc: WhatsApp and Messages in their own colours, any other
/// app in its own icon.
class _TargetDisc extends StatelessWidget {
  const _TargetDisc(this.target, {required this.extent});

  final ShareTarget target;
  final double extent;

  @override
  Widget build(BuildContext context) => switch (target.kind) {
    ShareTargetKind.whatsapp => _GradientDisc(
      colors: _whatsappGreen,
      child: WhatsAppGlyph(size: extent * 0.5),
    ),
    ShareTargetKind.messages => _GradientDisc(
      colors: _messagesBlue,
      child: Icon(
        CupertinoIcons.chat_bubble_text_fill,
        size: extent * 0.47,
        color: Colors.white,
      ),
    ),
    ShareTargetKind.app => _AppIconDisc(target, extent: extent),
  };
}

class _GradientDisc extends StatelessWidget {
  const _GradientDisc({required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
    ),
    child: Center(child: child),
  );
}

/// The app's own icon, round: an adaptive icon fills the disc, an old-style
/// one sits on white. Its initial until (or unless) the icon comes.
class _AppIconDisc extends StatelessWidget {
  const _AppIconDisc(this.target, {required this.extent});

  final ShareTarget target;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FutureBuilder<ShareTargetIcon?>(
      future: OutgoingFile.shareTargetIcon(target.id),
      builder: (context, snap) {
        final icon = snap.data;
        if (icon == null) {
          final initial = target.label.trim().characters.firstOrNull ?? '?';
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
            ),
            child: snap.connectionState == ConnectionState.done
                ? Center(
                    child: Text(
                      initial.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: extent * 0.38,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  )
                : null,
          );
        }
        final image = Image.memory(
          icon.png,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
        if (icon.adaptive) return ClipOval(child: image);
        return DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(padding: EdgeInsets.all(extent * 0.13), child: image),
        );
      },
    );
  }
}

class _MoreDisc extends StatelessWidget {
  const _MoreDisc({required this.extent});

  final double extent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHighest,
      ),
      child: Icon(
        CupertinoIcons.ellipsis,
        size: extent * 0.43,
        color: cs.onSurface,
      ),
    );
  }
}

/// "Add": an empty ring with a plus — room on the row for one more app.
class _AddDisc extends StatelessWidget {
  const _AddDisc({required this.extent});

  final double extent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Icon(
        CupertinoIcons.add,
        size: extent * 0.4,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// An app in the edit sheets: its disc, its name, and what it won't take.
class _AppTile extends StatelessWidget {
  const _AppTile({required this.target, required this.onTap});

  final ShareTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final only = switch ((target.takesImage, target.takesPdf)) {
      (true, false) => 'Images only',
      (false, true) => 'PDFs only',
      _ => null,
    };
    final subtitle = [?target.appLabel, ?only].join(' · ');
    return ListTile(
      leading: SizedBox.square(
        dimension: 40,
        child: _TargetDisc(target, extent: 40),
      ),
      title: Text(target.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Where there's no app to go to straight (iOS, the web): one full-width
/// capsule, ink on paper, to the system share sheet or a download.
class _PrimaryShareButton extends StatelessWidget {
  const _PrimaryShareButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ink = _inkOn(cs.onSurface);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: cs.onSurface,
        foregroundColor: ink,
        disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.5),
        disabledForegroundColor: ink,
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      icon: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            )
          : const Icon(CupertinoIcons.square_arrow_up, size: 20),
      label: Text(label),
    );
  }
}

/// The card as it will be sent, scaled down to fit a narrow screen — the
/// capture is always taken at the card's own 360-wide size.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.boundary, required this.child, super.key});

  final GlobalKey boundary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          // A dark card on a dark page needs an edge; elsewhere the shadow
          // is the edge.
          border: dark
              ? Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.55 : 0.16),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: RepaintBoundary(key: boundary, child: child),
        ),
      ),
    );
  }
}

/// What the PDF will be — a PDF can't be drawn here, so a page laid out the
/// way the real one is: the brand row, the title, its figures, the entries
/// and, when it's on, the very QR it will carry.
class _PdfPreview extends StatelessWidget {
  const _PdfPreview({
    required this.title,
    required this.period,
    required this.qr,
    super.key,
  });

  final String title;
  final String? period;
  final PaymentQr? qr;

  static const _ink = Color(0xFF0E0E10);
  static const _muted = Color(0xFF6B6B76);
  static const _panel = Color(0xFFF4F4F6);
  static const _bar = Color(0xFFE6E6EB);
  static const _width = 264.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final qr = this.qr;
    Widget bar(double width, {Color color = _bar, double height = 5}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );

    final page = Container(
      width: _width,
      height: _width * 1.414,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.55 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Inter', color: _ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(
                  size: 14,
                  tile: _ink,
                  ink: Colors.white,
                  radiusRim: false,
                ),
                const SizedBox(width: 5),
                const Text(
                  'XPENC',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                bar(46, height: 4),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              period ?? 'Every detail',
              style: const TextStyle(fontSize: 8.5, color: _muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          bar(28, height: 3),
                          bar(42, color: const Color(0xFFCFCFD6)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            bar(double.infinity, color: _panel, height: 9),
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  children: [
                    bar(26, height: 3.5),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: bar(60.0 + (i * 23) % 50, height: 3.5),
                      ),
                    ),
                    bar(30, height: 3.5),
                  ],
                ),
              ),
            const Spacer(),
            if (qr != null)
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  border: Border.all(color: _bar),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    QrImageView(
                      data: qr.link,
                      size: 40,
                      padding: EdgeInsets.zero,
                      gapless: true,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SCAN TO PAY',
                            style: TextStyle(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            MoneyFormat.forCurrency(
                              qr.amount,
                              MoneyFormat.currency,
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          Text(
                            '${qr.method} · ${qr.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 7, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              bar(120, height: 3.5),
          ],
        ),
      ),
    );

    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        page,
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.doc_text, size: 14, color: muted),
            const SizedBox(width: 6),
            Text(
              ['PDF', 'A4', ?period].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ],
    );
  }
}

/// Image ⇄ PDF as one sliding switch, iOS-style: a raised thumb glides to
/// the side picked — tap a side, or drag across. One fixed size on every
/// screen, its labels centred in it; a large text size shrinks them to fit.
class ShareFormatSlider extends StatelessWidget {
  const ShareFormatSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ShareFormat value;
  final ValueChanged<ShareFormat> onChanged;

  static const width = 232.0;
  static const height = 40.0;
  static const _inset = 3.0;

  static const _options = [
    (ShareFormat.image, CupertinoIcons.photo, 'Image'),
    (ShareFormat.pdf, CupertinoIcons.doc_text, 'PDF'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final track = cs.surfaceContainerHighest;
    final thumb = dark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.16), track)
        : Colors.white;
    // Narrower only where the screen itself is.
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          void dragTo(double dx) {
            final picked = dx < box.maxWidth / 2
                ? ShareFormat.image
                : ShareFormat.pdf;
            if (picked != value) onChanged(picked);
          }

          return GestureDetector(
            onHorizontalDragUpdate: (d) => dragTo(d.localPosition.dx),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_inset),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedAlign(
                        alignment: value == ShareFormat.image
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: thumb,
                              borderRadius: BorderRadius.circular(height / 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: dark ? 0.35 : 0.12,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          for (final (format, icon, label) in _options)
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: format == value,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onChanged(format),
                                  child: Center(
                                    child: _SliderLabel(
                                      icon: icon,
                                      label: label,
                                      selected: format == value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: selected ? cs.onSurface : cs.onSurfaceVariant),
      duration: const Duration(milliseconds: 200),
      builder: (context, color, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // Shrinks rather than clips at a large text size.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
