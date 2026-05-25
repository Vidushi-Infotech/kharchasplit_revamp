import 'package:flutter/material.dart';

/// One onboarding slide. The visual hierarchy is intentional:
/// 1. A component "preview" hero — a tightly styled mini mockup of the
///    real feature.
/// 2. A bold display headline.
/// 3. A short, muted body line.
///
/// The slide is built against a force-dark palette so the tour reads as a
/// single, cohesive surface regardless of the user's system theme.
class OnboardingSlideWidget extends StatelessWidget {
  final Widget preview;
  final String headline;
  final String body;
  final bool isWeb;
  final bool isTablet;

  const OnboardingSlideWidget({
    Key? key,
    required this.preview,
    required this.headline,
    required this.body,
    this.isWeb = false,
    this.isTablet = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Force-dark colors so the tour stays consistent regardless of theme.
    const onSurface = Color(0xFFFFFFFF);
    const onSurfaceMuted = Color(0xFF9AA3B0);

    final headlineSize = isWeb
        ? 44.0
        : isTablet
            ? 36.0
            : 32.0;
    final bodySize = isWeb
        ? 17.0
        : isTablet
            ? 16.0
            : 15.0;
    final horizontalPadding = isWeb
        ? 40.0
        : isTablet
            ? 32.0
            : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Preview hero. The widget is responsible for its own internal
          // padding/styling; we just give it consistent breathing room.
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb
                    ? 480
                    : isTablet
                        ? 420
                        : 360,
              ),
              child: preview,
            ),
          ),
          SizedBox(height: isWeb ? 56 : 40),
          // Headline — big, tight, white. Letter-spacing tightened so it
          // reads as a poster rather than UI text.
          Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface,
              fontWeight: FontWeight.w800,
              fontSize: headlineSize,
              height: 1.05,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 14),
          // Body — muted, generous line-height. Limit width on tablet/web
          // so it doesn't span the whole column.
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWeb ? 480 : 360,
              ),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onSurfaceMuted,
                  fontSize: bodySize,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
