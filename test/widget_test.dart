import 'package:attendence_tracker_admin/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserModel parses Firestore-like json', () {
    const source = {
      'email': 'doctor@example.com',
      'fullName': 'Dr. Test',
      'role': 'doctor',
      'uid': 'abc123',
    };

    final user = UserModel.fromJson(source);

    expect(user.email, 'doctor@example.com');
    expect(user.fullName, 'Dr. Test');
    expect(user.role, 'doctor');
    expect(user.uid, 'abc123');
    expect(user.isDoctor, isTrue);
  });
}
