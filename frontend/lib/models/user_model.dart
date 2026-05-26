import 'package:equatable/equatable.dart';

/// User model representing a person in the app
class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String preferredCurrency;
  final double totalOwed;
  final double totalOwing;
  final DateTime createdAt;
  final bool isPlaceholder;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.preferredCurrency = 'INR',
    this.totalOwed = 0,
    this.totalOwing = 0,
    required this.createdAt,
    this.isPlaceholder = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] ?? json['createdAt'] ?? json['joinedAt'];
    return UserModel(
      id: (json['id'] ?? json['userId'] ?? '') as String,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phoneNumber'] ?? json['phone_number'] ?? json['phone'] ?? '')
          as String,
      avatarUrl: (json['profileImageBase64'] ??
          json['profileImage'] ??
          json['avatar_url'] ??
          json['avatarUrl']) as String?,
      preferredCurrency: (json['preferredCurrency'] ??
              json['preferred_currency'] ??
              'INR') as String,
      totalOwed: (json['totalOwed'] as num?)?.toDouble() ?? 0,
      totalOwing: (json['totalOwing'] as num?)?.toDouble() ?? 0,
      createdAt: created is String ? DateTime.parse(created) : DateTime.now(),
      isPlaceholder: (json['isPlaceholder'] ?? json['is_placeholder'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phoneNumber': phone,
        if (avatarUrl != null) 'profileImageBase64': avatarUrl,
        'preferredCurrency': preferredCurrency,
        'totalOwed': totalOwed,
        'totalOwing': totalOwing,
        'createdAt': createdAt.toIso8601String(),
        'isPlaceholder': isPlaceholder,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? preferredCurrency,
    double? totalOwed,
    double? totalOwing,
    DateTime? createdAt,
    bool? isPlaceholder,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      totalOwed: totalOwed ?? this.totalOwed,
      totalOwing: totalOwing ?? this.totalOwing,
      createdAt: createdAt ?? this.createdAt,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        avatarUrl,
        preferredCurrency,
        totalOwed,
        totalOwing,
        createdAt,
        isPlaceholder,
      ];
}
