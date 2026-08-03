import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/assets.dart';
import '../theme/colors.dart';

/// Capital BullWave (CBW) mark — splash, onboarding, login, headers.
class AppBrandLogo extends StatelessWidget {
  final double size;
  final bool showShadow;
  final bool rounded;
  final bool useFullLogo;

  const AppBrandLogo({
    super.key,
    this.size = 72,
    this.showShadow = true,
    this.rounded = true,
    this.useFullLogo = true,
  });

  static const _logoAspectRatio = 819 / 1024;

  @override
  Widget build(BuildContext context) {
    if (useFullLogo) {
      final height = size;
      final width = size * _logoAspectRatio;
      final radius = rounded ? size * 0.14 : 0.0;

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.28),
                    blurRadius: size * 0.28,
                    offset: Offset(0, size * 0.06),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: Image.asset(
              AppAssets.capitalBullwaveLogo,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

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

/// Large hero logo for splash and onboarding.
class CapitalBullWaveHeroLogo extends StatelessWidget {
  final double height;
  final bool showShadow;

  const CapitalBullWaveHeroLogo({
    super.key,
    this.height = 168,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBrandLogo(
      size: height,
      showShadow: showShadow,
      rounded: true,
      useFullLogo: true,
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
