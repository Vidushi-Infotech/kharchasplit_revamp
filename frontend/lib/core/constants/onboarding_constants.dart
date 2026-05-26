import 'package:flutter/material.dart';

/// Data model for onboarding pages
class OnboardingPageData {
  final String title;
  final String heading;
  final String description;
  final Color backgroundColor;
  final IconData iconPlaceholder;

  const OnboardingPageData({
    required this.title,
    required this.heading,
    required this.description,
    required this.backgroundColor,
    required this.iconPlaceholder,
  });
}

/// Onboarding pages configuration
final List<OnboardingPageData> onboardingPages = [
  OnboardingPageData(
    title: 'Welcome to Kharchasplit 1',
    heading: 'Effortless Expense Sharing',
    description: 'Easily split bills with friends and family.',
    backgroundColor: const Color(0xFFE8F5E9),
    iconPlaceholder: Icons.calculate,
  ),
  OnboardingPageData(
    title: 'Welcome to Kharchasplit 2',
    heading: 'Track Expenses',
    description: 'Keep track of who owes what and settle up easily.',
    backgroundColor: const Color(0xFFFFE8D6),
    iconPlaceholder: Icons.trending_up,
  ),
  OnboardingPageData(
    title: 'Welcome to Kharchasplit 3',
    heading: 'Manage Groups',
    description: 'Create groups for trips, events, and more.',
    backgroundColor: const Color(0xFFE1F5FE),
    iconPlaceholder: Icons.group,
  ),
];
