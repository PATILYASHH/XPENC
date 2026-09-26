import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';

/// Small pill naming the group a transaction or person entry came from.
/// Tapping it opens that group.
class GroupTag extends StatelessWidget {
  const GroupTag({required this.group, super.key});

  final GroupRow group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/group/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_2_outlined, size: 13, color: cs.onSurface),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
