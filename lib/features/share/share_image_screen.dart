import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/security/nct.dart';
import '../../core/widgets/app_surfaces.dart';
import 'share_cards.dart';
import 'share_files.dart';
import 'share_models.dart';

/// Shows the card exactly as it will be sent — with a Dark/Light switch and,
/// for a ledger, a period switch — then captures it at 3× (a 1080 px wide
/// PNG) and hands it to the share sheet.
class ShareImageScreen extends StatefulWidget {
  const ShareImageScreen({
    required this.title,
    required this.fileStem,
    required this.subject,
    required this.builder,
    this.periods = const [],
    this.secure = false,
    super.key,
  });

  final String title;

  /// The PNG's name, without extension.
  final String fileStem;
  final String subject;

  /// Builds the card for the chosen look and period.
  final Widget Function(ShareCardTone tone, SharePeriod period) builder;

  /// Offered as a switch when there's more than one; the first is the
  /// default. Empty = the card has no period ([SharePeriod.allTime]).
  final List<SharePeriod> periods;

  /// Keeps captures blocked while it's open — an NCT transaction (GitHub
  /// #143) is only ever on screen in the clear on a secure window.
  final bool secure;

  @override
  State<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends State<ShareImageScreen> {
  final _boundary = GlobalKey();
  var _tone = ShareCardTone.dark;
  var _periodIndex = 0;
  var _busy = false;

  SharePeriod get _period => widget.periods.isEmpty
      ? SharePeriod.allTime
      : widget.periods[_periodIndex];

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // The frame showing the current choice has to be painted first.
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = await writeShareFile(
        png!.buffer.asUint8List(),
        '${widget.fileStem}.png',
      );
      await shareFile(file, mimeType: 'image/png', subject: widget.subject);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't create the image: $e")),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  // Scaled down to fit a narrow screen; the capture is
                  // always taken at the card's own 360-wide size.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: RepaintBoundary(
                          key: _boundary,
                          child: widget.builder(_tone, _period),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.periods.length > 1) ...[
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          for (var i = 0; i < widget.periods.length; i++)
                            ButtonSegment(
                              value: i,
                              label: Text(widget.periods[i].label),
                            ),
                        ],
                        selected: {_periodIndex},
                        onSelectionChanged: (s) =>
                            setState(() => _periodIndex = s.first),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _busy ? null : _share,
                            icon: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const AppIcon(Icons.ios_share_rounded),
                            label: const Text('Share image'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
