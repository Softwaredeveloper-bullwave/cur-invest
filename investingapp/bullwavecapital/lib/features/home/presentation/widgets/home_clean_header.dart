import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/constants/brand.dart';
import '../../../../core/utils/formatters.dart';
import 'home_theme_a.dart';

class HomeCleanHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationTap;
  final int notificationCount;
  final String? userName;

  const HomeCleanHeader({
    super.key,
    this.onMenuTap,
    this.onNotificationTap,
    this.notificationCount = 0,
    this.userName,
  });

  String get _firstName {
    final name = userName?.trim();
    if (name == null || name.isEmpty) return 'Investor';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                GreetingHelper.getGreeting(),
                style: ThemeAType.secondary(size: 13, color: p.textGrey),
              ),
              const SizedBox(height: 2),
              Text(
                _firstName,
                style: ThemeAType.heading(size: 26, color: p.textDark),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: p.primaryBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      AppBrand.acronym,
                      style: ThemeAType.label(size: 10, color: p.primaryDark)
                          .copyWith(
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppBrand.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeAType.label(size: 11, color: p.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            _HeaderIconButton(
              icon: PhosphorIcons.bell,
              onTap: onNotificationTap,
              badge: notificationCount,
            ),
            const SizedBox(width: 8),
            _HeaderIconButton(icon: PhosphorIcons.list, onTap: onMenuTap),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badge;

  const _HeaderIconButton({required this.icon, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.card.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: p.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: p.isDark ? 0.35 : 0.06,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: p.textDark),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.bg, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: ThemeAType.label(
                  size: 9,
                  color: p.onPrimary,
                ).copyWith(height: 1),
              ),
            ),
          ),
      ],
    );
  }
}
