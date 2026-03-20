import 'package:flutter/material.dart';
import '../../../../core/constants/onboarding_constants.dart';

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingPageData pageData;
  final bool isWeb;
  final bool isTablet;

  const OnboardingPageWidget({
    Key? key,
    required this.pageData,
    required this.isWeb,
    required this.isTablet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final illustrationSize = isWeb ? 280.0 : isTablet ? 200.0 : 150.0;
    final titleFontSize = isWeb ? 18.0 : isTablet ? 16.0 : 14.0;
    final headingFontSize = isWeb ? 28.0 : isTablet ? 24.0 : 20.0;
    final descriptionFontSize = isWeb ? 16.0 : isTablet ? 14.0 : 12.0;

    return Card(
      margin: EdgeInsets.all(isWeb ? 20 : isTablet ? 12 : 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: pageData.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 40 : isTablet ? 24 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                pageData.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: titleFontSize,
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isWeb ? 24 : 12),

              // Illustration Placeholder
              RepaintBoundary(
                child: Container(
                  width: illustrationSize,
                  height: illustrationSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        pageData.iconPlaceholder,
                        size: isWeb ? 80 : isTablet ? 60 : 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add illustration here',
                        style: TextStyle(
                          fontSize: descriptionFontSize - 2,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isWeb ? 32 : isTablet ? 20 : 16),

              // Heading
              Text(
                pageData.heading,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: headingFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isWeb ? 16 : 12),

              // Description
              Text(
                pageData.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: descriptionFontSize,
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
