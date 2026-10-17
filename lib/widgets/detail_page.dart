import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/density.dart';
import 'cards.dart';
import '../core/palette.dart';

/// Shared scaffold for every pushed detail page (order, customer, profile,
/// insights…). Keeps one consistent back-header: breadcrumb eyebrow, big
/// title, optional trailing actions, then a scrollable body.
class DetailPage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final List<Widget> actions;
  final Widget body;
  final bool showIcon;

  const DetailPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.subtitle,
    this.icon = Icons.article_outlined,
    this.iconColor,
    this.iconBg,
    this.actions = const [],
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = this.iconColor ?? AppPalette.primary;
    final iconBg = this.iconBg ?? AppPalette.primarySoft;
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(Density.pagePad(context), 12,
                  Density.pagePad(context), 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _BackPill(),
                  const SizedBox(width: 10),
                  if (showIcon) ...[
                    IconChipLite(
                        icon: icon, color: iconColor, bg: iconBg, size: 38),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(eyebrow),
                        const SizedBox(height: 3),
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: Density.compact(context) ? 17 : 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                                color: AppPalette.ink)),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.fromLTRB(Density.pagePad(context), 0,
                    Density.pagePad(context), 10),
                child: Text(subtitle!,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppPalette.muted)),
              ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(Density.pagePad(context), 16,
                    Density.pagePad(context), 28),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.stroke),
          ),
          child:
              Icon(Icons.arrow_back_rounded, size: 18, color: AppPalette.body),
        ),
      ),
    );
  }
}
