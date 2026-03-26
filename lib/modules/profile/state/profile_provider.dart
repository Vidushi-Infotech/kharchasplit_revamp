import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/avatar_generator_service.dart';

class ProfileState {
  final String userName;
  final String email;
  final String? phone;
  final String? photoPath;
  final AvatarStyle? selectedAvatarStyle;

  const ProfileState({
    required this.userName,
    required this.email,
    this.phone,
    this.photoPath,
    this.selectedAvatarStyle = AvatarStyle.gradient,
  });

  ProfileState copyWith({
    String? userName,
    String? email,
    String? phone,
    String? photoPath,
    AvatarStyle? selectedAvatarStyle,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
      selectedAvatarStyle: selectedAvatarStyle ?? this.selectedAvatarStyle,
    );
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState(
    userName: 'You',
    email: 'user@example.com',
    phone: '+91 98765 43210',
    photoPath: null,
    selectedAvatarStyle: AvatarStyle.gradient,
  );

  void updateUserName(String name) {
    state = state.copyWith(userName: name);
  }

  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  void updatePhone(String phone) {
    state = state.copyWith(phone: phone);
  }

  void setPhotoPath(String path) {
    state = state.copyWith(photoPath: path);
  }

  void clearPhoto() {
    state = state.copyWith(photoPath: null);
  }

  void setAvatarStyle(AvatarStyle style) {
    state = state.copyWith(selectedAvatarStyle: style);
  }
}
