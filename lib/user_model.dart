class UserModel {
  const UserModel({
    required this.email,
    required this.fullName,
    required this.role,
    required this.uid,
  });

  final String email;
  final String fullName;
  final String role;
  final String uid;

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isDoctor => role.toLowerCase() == 'doctor';
  bool get isStudent => role.toLowerCase() == 'student';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: (json['email'] ?? '') as String,
      fullName: (json['fullName'] ?? 'Unknown User') as String,
      role: (json['role'] ?? 'student') as String,
      uid: (json['uid'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role,
      'uid': uid,
    };
  }
}
