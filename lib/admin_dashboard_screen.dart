import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'admin_login_screen.dart';
import 'login_controller.dart';
import 'user_model.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>(tag: 'login_controller');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Admin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Obx(() => Text(
                  'Signed in as ${controller.currentAdmin.value?.fullName ?? 'Administrator'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF667085),
                      ),
                )),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await controller.logout();
              Get.offAll(() => const AdminLoginScreen());
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: controller.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return _DashboardError(message: '${usersSnapshot.error}');
          }
          if (!usersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = usersSnapshot.data!;
          final usersById = {for (final user in users) user.uid: user};
          final doctors = users.where((user) => user.isDoctor).toList();
          final students = users.where((user) => user.isStudent).toList();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: controller.watchLectures(),
            builder: (context, lecturesSnapshot) {
              if (lecturesSnapshot.hasError) {
                return _DashboardError(message: '${lecturesSnapshot.error}');
              }
              if (!lecturesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final lectures = lecturesSnapshot.data!.docs;
              final isCompact = MediaQuery.of(context).size.width < 980;
              final uniqueCourses = lectures
                  .map((lecture) => lecture.data()['courseCode']?.toString() ?? '')
                  .where((course) => course.isNotEmpty)
                  .toSet()
                  .length;
              final totalAttendanceMarks = lectures.fold<int>(
                0,
                (sum, lecture) {
                  final attendancePerDay = Map<String, dynamic>.from(
                    lecture.data()['attendancePerDay'] ?? const {},
                  );
                  final marks = attendancePerDay.values.fold<int>(
                    0,
                    (inner, value) => inner + List<String>.from(value).length,
                  );
                  return sum + marks;
                },
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _StatCard(
                          title: 'Doctors',
                          value: doctors.length.toString(),
                          subtitle: 'Accounts created for lecturers',
                          icon: Icons.badge_outlined,
                          color: const Color(0xFF0F766E),
                        ),
                        _StatCard(
                          title: 'Students',
                          value: students.length.toString(),
                          subtitle: 'User records with student role',
                          icon: Icons.groups_2_outlined,
                          color: const Color(0xFF2563EB),
                        ),
                        _StatCard(
                          title: 'Lectures',
                          value: lectures.length.toString(),
                          subtitle: 'Lecture documents in Firestore',
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFFEA580C),
                        ),
                        _StatCard(
                          title: 'Courses',
                          value: uniqueCourses.toString(),
                          subtitle: 'Unique course codes across lectures',
                          icon: Icons.school_outlined,
                          color: const Color(0xFF7C3AED),
                        ),
                        _StatCard(
                          title: 'Attendance Marks',
                          value: totalAttendanceMarks.toString(),
                          subtitle: 'Saved attendance records across all days',
                          icon: Icons.how_to_reg_rounded,
                          color: const Color(0xFF027A48),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isCompact) ...[
                      _DoctorsCard(doctors: doctors),
                      const SizedBox(height: 20),
                      _UsersCard(users: users),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _DoctorsCard(doctors: doctors)),
                          const SizedBox(width: 20),
                          Expanded(child: _UsersCard(users: users)),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _LecturesCard(lectures: lectures, usersById: usersById),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _CreateDoctorDialog(),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Create doctor'),
      ),
    );
  }
}

class _DoctorsCard extends StatelessWidget {
  const _DoctorsCard({required this.doctors});

  final List<UserModel> doctors;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Doctor accounts',
      subtitle: 'Create and review doctor access.',
      trailing: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _CreateDoctorDialog(),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New doctor'),
      ),
      child: doctors.isEmpty
          ? const _EmptyPanel(message: 'No doctor accounts found yet.')
          : Column(
              children: doctors
                  .map(
                    (doctor) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        foregroundColor: const Color(0xFF0F766E),
                        child: Text(
                          doctor.fullName.isEmpty ? '?' : doctor.fullName[0].toUpperCase(),
                        ),
                      ),
                      title: Text(doctor.fullName),
                      subtitle: Text(doctor.email),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _UsersCard extends StatelessWidget {
  const _UsersCard({required this.users});

  final List<UserModel> users;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'User directory',
      subtitle: 'All accounts from the users collection.',
      child: users.isEmpty
          ? const _EmptyPanel(message: 'No users found.')
          : SizedBox(
              height: 340,
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(user.fullName),
                    subtitle: Text(user.email),
                    trailing: _RoleBadge(role: user.role),
                  );
                },
              ),
            ),
    );
  }
}

class _LecturesCard extends StatelessWidget {
  const _LecturesCard({
    required this.lectures,
    required this.usersById,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> lectures;
  final Map<String, UserModel> usersById;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Lectures, QR codes, and attendance',
      subtitle: 'Inspect every lecture and the users who watched it.',
      child: lectures.isEmpty
          ? const _EmptyPanel(message: 'No lectures found in Firestore.')
          : Column(
              children: lectures.map((lecture) {
                final data = lecture.data();
                final doctor = usersById[data['doctorId']]?.fullName ?? 'Unknown doctor';
                final students = List<String>.from(data['students'] ?? const []);
                final daysOfWeek = List<String>.from(data['daysOfWeek'] ?? const []);
                final attendancePerDay =
                    Map<String, dynamic>.from(data['attendancePerDay'] ?? const {});
                final courseCode = data['courseCode']?.toString() ?? 'No course code';
                final section = data['section']?.toString() ?? 'No section';
                final room = data['room']?.toString() ?? 'No room';
                final attendanceMarks = attendancePerDay.values.fold<int>(
                  0,
                  (sum, value) => sum + List<String>.from(value).length,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    title: Text(
                      data['title']?.toString() ?? 'Untitled lecture',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    subtitle: Text(
                      '${_formatDate(data['dateTime'])} - $doctor - $courseCode',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF667085),
                          ),
                    ),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetaBox(label: 'Lecture ID', value: lecture.id),
                          _MetaBox(label: 'Doctor', value: doctor),
                          _MetaBox(label: 'Course Code', value: courseCode),
                          _MetaBox(label: 'Section', value: section),
                          _MetaBox(label: 'Room', value: room),
                          _MetaBox(
                            label: 'QR Hash',
                            value: data['qrHash']?.toString() ?? 'No QR hash',
                          ),
                          _MetaBox(
                            label: 'Days',
                            value: daysOfWeek.isEmpty ? 'Not set' : daysOfWeek.join(', '),
                          ),
                          _MetaBox(
                            label: 'Attendance Marks',
                            value: attendanceMarks.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => _QrDialog(
                              title: data['title']?.toString() ?? 'Lecture QR',
                              value: data['qrHash']?.toString() ?? lecture.id,
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_rounded),
                          label: const Text('Preview QR code'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AttendanceView(
                        usersById: usersById,
                        studentIds: students,
                        attendancePerDay: attendancePerDay,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  static String _formatDate(dynamic rawDate) {
    DateTime? date;
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate);
    } else if (rawDate is DateTime) {
      date = rawDate;
    }

    if (date == null) {
      return 'Unknown date';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour:$minute $suffix';
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView({
    required this.usersById,
    required this.studentIds,
    required this.attendancePerDay,
  });

  final Map<String, UserModel> usersById;
  final List<String> studentIds;
  final Map<String, dynamic> attendancePerDay;

  @override
  Widget build(BuildContext context) {
    final names = studentIds.map((id) => usersById[id]?.fullName ?? id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users who watched / attended',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        names.isEmpty
            ? const _EmptyPanel(message: 'This lecture has no linked students.')
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: names
                    .map(
                      (name) => Chip(
                        label: Text(name),
                        avatar: const Icon(Icons.person_outline_rounded, size: 18),
                        backgroundColor: const Color(0xFFEEF4FF),
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
        const SizedBox(height: 18),
        Text(
          'Attendance per day',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        attendancePerDay.isEmpty
            ? const _EmptyPanel(message: 'No attendance-per-day entries found.')
            : Column(
                children: attendancePerDay.entries.map((entry) {
                  final attendees = List<String>.from(entry.value ?? const []);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Day ${entry.key}'),
                        const SizedBox(height: 10),
                        attendees.isEmpty
                            ? const Text('No attendees saved for this day.')
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: attendees
                                    .map(
                                      (uid) => Chip(
                                        label: Text(usersById[uid]?.fullName ?? uid),
                                        backgroundColor: const Color(0xFFECFDF3),
                                        side: BorderSide.none,
                                      ),
                                    )
                                    .toList(),
                              ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _CreateDoctorDialog extends StatefulWidget {
  const _CreateDoctorDialog();

  @override
  State<_CreateDoctorDialog> createState() => _CreateDoctorDialogState();
}

class _CreateDoctorDialogState extends State<_CreateDoctorDialog> {
  final _controller = Get.find<LoginController>(tag: 'login_controller');
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await _controller.createDoctorAccount(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.snackbar(
        'Success',
        'Doctor account created successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF0F766E),
        colorText: Colors.white,
      );
    } catch (error) {
      Get.snackbar(
        'Error',
        error.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFB42318),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Create doctor account'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Email is required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Password is required';
                  if (value.length < 6) return 'Password should be at least 6 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Obx(() {
          final isLoading =
              _controller.createDoctorStatus.value == AuthRequestStatus.loading;
          return FilledButton(
            onPressed: isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            child: Text(isLoading ? 'Creating...' : 'Create doctor'),
          );
        }),
      ],
    );
  }
}

class _QrDialog extends StatelessWidget {
  const _QrDialog({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: value,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            SelectableText(value, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 18),
          Text(title),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF667085),
                          ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF667085),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role.toLowerCase()) {
      'admin' => const Color(0xFF7C3AED),
      'doctor' => const Color(0xFF0F766E),
      _ => const Color(0xFF2563EB),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF667085),
            ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _PanelCard(
          title: 'Firebase load error',
          subtitle: 'The dashboard could not build from Firestore data.',
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFB42318),
                ),
          ),
        ),
      ),
    );
  }
}
