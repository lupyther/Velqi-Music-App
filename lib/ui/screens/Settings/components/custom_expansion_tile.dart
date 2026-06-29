import 'package:flutter/material.dart';

class CustomExpansionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const CustomExpansionTile({
    super.key,
    required this.children,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withAlpha(80), width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: ExpansionTile(
          collapsedBackgroundColor: Colors.transparent,
          backgroundColor: cs.surface.withAlpha(25),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding:
              const EdgeInsets.only(right: 12, left: 6, top: 6, bottom: 6),
          childrenPadding: EdgeInsets.zero,
          textColor: textTheme.titleMedium?.color,
          iconColor: textTheme.titleMedium?.color,
          title: Text(
            title,
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.secondary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Column(
                children: children.map((child) {
                  if (child is ListTile) {
                    return Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: cs.outline.withAlpha(35), width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: child,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: child,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
