import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass.dart';

/// A person's avatar: their imported contact photo if they have one,
/// otherwise the same two-letter-initials circle every person list showed
/// before photo import existed.
///
/// [photoPath] points at a file `PersonPhotoStorage` wrote — checked with
/// `existsSync` rather than trusted blindly, since the file backing an old
/// path can disappear (app storage cleared, restored from a backup made on
/// another device) without the database row knowing.
///
/// Under Glass a photo lights the card around it with its own colour (see
/// [photoAmbientColor]); [glow] turns that off where there's no card to
/// light — a chip, a title.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    this.photoPath,
    this.radius,
    this.glow = true,
    super.key,
  });

  final String name;
  final String? photoPath;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null && File(path).existsSync()) {
      final avatar = CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path)),
      );
      if (!glow || !AppSurface.of(context).isGlass) return avatar;
      // CircleAvatar's own default radius.
      return _PhotoGlow(path: path, radius: radius ?? 20, child: avatar);
    }
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundColor: theme.colorScheme.onSurface,
      child: Text(
        personInitials(name),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: radius == null ? null : radius! * 0.75,
        ),
      ),
    );
  }
}

/// The ambient light a photo casts on the card it sits in: a soft pool of
/// the photo's own colour, centred on it and fading out a little way
/// beyond, the way a lit screen colours the desk around it. A gradient, not
/// a blur of the photo — it costs nothing per frame while a list scrolls.
class _PhotoGlow extends StatefulWidget {
  const _PhotoGlow({
    required this.path,
    required this.radius,
    required this.child,
  });

  final String path;
  final double radius;
  final Widget child;

  @override
  State<_PhotoGlow> createState() => _PhotoGlowState();
}

class _PhotoGlowState extends State<_PhotoGlow> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_PhotoGlow old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _color = null;
      _resolve();
    }
  }

  void _resolve() {
    final path = widget.path;
    if (_ambientCache.containsKey(path)) {
      _color = _ambientCache[path];
      return;
    }
    photoAmbientColor(path).then((color) {
      if (mounted && widget.path == path) setState(() => _color = color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final reach = widget.radius * 1.7;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -reach,
          top: -reach,
          right: -reach,
          bottom: -reach,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: color == null ? 0 : 1,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOut,
              child: color == null
                  ? const SizedBox.expand()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.5),
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0),
                          ],
                          stops: const [0.3, 0.58, 1],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

final _ambientCache = <String, Color?>{};
final _ambientPending = <String, Future<Color?>>{};

/// The colour a photo lights its surroundings with: its pixels averaged with
/// the vivid ones counting most (a face on a grey wall should glow the
/// colour of the shirt, not the wall), then lifted to a glow's saturation
/// and brightness. `null` when the file can't be decoded. Cached per path —
/// `PersonPhotoStorage` never reuses one.
Future<Color?> photoAmbientColor(String path) {
  if (_ambientCache.containsKey(path)) {
    return SynchronousFuture(_ambientCache[path]);
  }
  return _ambientPending[path] ??= _sample(path).then((color) {
    _ambientCache[path] = color;
    _ambientPending.remove(path);
    return color;
  });
}

Future<Color?> _sample(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 16,
      targetHeight: 16,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();
    if (data == null) return null;
    return ambientFromRgba(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

/// [photoAmbientColor]'s averaging, over raw RGBA bytes.
@visibleForTesting
Color? ambientFromRgba(Uint8List rgba) {
  var r = 0.0, g = 0.0, b = 0.0, w = 0.0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final pr = rgba[i] / 255;
    final pg = rgba[i + 1] / 255;
    final pb = rgba[i + 2] / 255;
    final alpha = rgba[i + 3] / 255;
    final hi = math.max(pr, math.max(pg, pb));
    final lo = math.min(pr, math.min(pg, pb));
    final chroma = hi - lo;
    // Vivid pixels carry the light; near-black ones hardly any.
    final weight = alpha * (0.06 + 4 * chroma * chroma) * (hi < 0.1 ? 0.2 : 1);
    r += pr * weight;
    g += pg * weight;
    b += pb * weight;
    w += weight;
  }
  if (w <= 0) return null;
  final hsl = HSLColor.fromColor(
    Color.from(alpha: 1, red: r / w, green: g / w, blue: b / w),
  );
  return hsl
      .withSaturation((hsl.saturation * 1.35).clamp(0.0, 1.0))
      .withLightness(hsl.lightness.clamp(0.45, 0.65))
      .toColor();
}

/// Two-letter initials from a name, e.g. "Rahul Kumar" -> "RK". The single
/// source of truth for this — previously duplicated between
/// `persons_screen.dart` and `archived_persons_screen.dart`.
String personInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
