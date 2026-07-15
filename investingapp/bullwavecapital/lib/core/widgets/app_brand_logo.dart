import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/assets.dart';
import '../theme/colors.dart';

/// Symmetric BullWave mark — splash, login, headers.
class AppBrandLogo extends StatelessWidget {
  final double size;
  final bool showShadow;
  final bool rounded;

  const AppBrandLogo({
    super.key,
    this.size = 72,
    this.showShadow = true,
    this.rounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = rounded ? size * 0.28 : 0.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.brandPink.withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.asset(
          AppAssets.logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Tintable SVG glyph for navigation and inline UI.
class AppSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final Gradient? gradient;

  const AppSvgIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: gradient == null && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );

    if (gradient == null) return picture;

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient!.createShader(bounds),
      child: picture,
    );
  }
}
