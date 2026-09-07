import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/keep_alive_for.dart';

/// A single section of a policy document — heading + paragraphs.
class PolicySection {
  const PolicySection({required this.heading, required this.paragraphs});
  final String heading;
  final List<String> paragraphs;

  factory PolicySection.fromJson(Map<String, dynamic> json) {
    final raw = json['paragraphs'];
    return PolicySection(
      heading: (json['heading'] as String?) ?? '',
      paragraphs: raw is List
          ? raw.map((p) => p.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}

class PolicyDocument {
  const PolicyDocument({
    required this.title,
    required this.version,
    required this.lastUpdatedAt,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String version;
  final String lastUpdatedAt;
  final String intro;
  final List<PolicySection> sections;

  factory PolicyDocument.fromJson(Map<String, dynamic> json) {
    final raw = json['sections'];
    return PolicyDocument(
      title: (json['title'] as String?) ?? 'Policy',
      version: (json['version'] as String?) ?? '',
      lastUpdatedAt: (json['lastUpdatedAt'] as String?) ?? '',
      intro: (json['intro'] as String?) ?? '',
      sections: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(PolicySection.fromJson)
              .toList(growable: false)
          : const <PolicySection>[],
    );
  }
}

/// `kind` is the path segment after `/policies/` — e.g. `privacy` or `terms`.
final policyProvider =
    FutureProvider.autoDispose.family<PolicyDocument, String>((ref, kind) async {
  keepAliveFor(ref, const Duration(minutes: 30));
  final client = ref.read(apiClientProvider);
  final res = await client.dio.get('/policies/$kind');
  final body = res.data;
  if (body is! Map ||
      body['success'] != true ||
      body['data'] is! Map<String, dynamic>) {
    throw Exception('Malformed policy response');
  }
  return PolicyDocument.fromJson(body['data'] as Map<String, dynamic>);
});
