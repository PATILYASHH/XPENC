import 'dart:io';

import 'package:flutter/material.dart';

/// A person's avatar: their imported contact photo if they have one,
/// otherwise the same two-letter-initials circle every person list showed
/// before photo import existed.
///
/// [photoPath] points at a file `PersonPhotoStorage` wrote — checked with
/// `existsSync` rather than trusted blindly, since the file backing an old
/// path can disappear (app storage cleared, restored from a backup made on
/// another device) without the database row knowing.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    this.photoPath,
    this.radius,
    super.key,
  });

  final String name;
  final String? photoPath;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path)),
      );
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
