/// Contact model matching React Native structure
class ContactModel {
  final String recordId;
  final String displayName;
  final List<String> phoneNumbers;
  final List<String> emailAddresses;
  final String? thumbnailPath;

  const ContactModel({
    required this.recordId,
    required this.displayName,
    required this.phoneNumbers,
    required this.emailAddresses,
    this.thumbnailPath,
  });

  /// Get primary phone number (first one)
  String? get primaryPhone => phoneNumbers.isNotEmpty ? phoneNumbers.first : null;

  /// Get primary email (first one)
  String? get primaryEmail => emailAddresses.isNotEmpty ? emailAddresses.first : null;

  /// Get initials from display name
  String get initials {
    final names = displayName.split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0][0].toUpperCase();
    return (names[0][0] + names[1][0]).toUpperCase();
  }

  @override
  String toString() => 'ContactModel($displayName, $primaryPhone)';
}

/// Extended contact with registration info
class ExtendedContactModel extends ContactModel {
  final bool isRegistered;
  final Map<String, dynamic>? userProfile;

  const ExtendedContactModel({
    required String recordId,
    required String displayName,
    required List<String> phoneNumbers,
    required List<String> emailAddresses,
    String? thumbnailPath,
    required this.isRegistered,
    this.userProfile,
  }) : super(
    recordId: recordId,
    displayName: displayName,
    phoneNumbers: phoneNumbers,
    emailAddresses: emailAddresses,
    thumbnailPath: thumbnailPath,
  );

  /// Create from ContactModel with registration info
  factory ExtendedContactModel.from(
    ContactModel contact, {
    required bool isRegistered,
    Map<String, dynamic>? userProfile,
  }) {
    return ExtendedContactModel(
      recordId: contact.recordId,
      displayName: contact.displayName,
      phoneNumbers: contact.phoneNumbers,
      emailAddresses: contact.emailAddresses,
      thumbnailPath: contact.thumbnailPath,
      isRegistered: isRegistered,
      userProfile: userProfile,
    );
  }
}
