import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

class CreatedUserResult {
  final String uid;
  final String temporaryPassword;

  const CreatedUserResult({
    required this.uid,
    required this.temporaryPassword,
  });
}

class UserAccountService {
  UserAccountService._();

  static String normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'manager') return 'admin';
    if (normalized == 'system support') return 'employee';
    return normalized;
  }

  static bool isAdminRole(String role) => normalizeRole(role) == 'admin';

  static bool isEmployeeRole(String role) => normalizeRole(role) == 'employee';

  static bool isGrowerRole(String role) => normalizeRole(role) == 'grower';

  static String generateSecurePassword({int length = 18}) {
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = r'!@#$%^&*()-_=+[]{};:,.?';
    const all = '$lower$upper$numbers$symbols';
    final random = Random.secure();

    final chars = <String>[
      lower[random.nextInt(lower.length)],
      upper[random.nextInt(upper.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    while (chars.length < length) {
      chars.add(all[random.nextInt(all.length)]);
    }
    chars.shuffle(random);
    return chars.join();
  }

  static Future<CreatedUserResult> createManagedUser({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    String phoneNumber = '',
    String address = '',
    String status = 'active',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedRole = normalizeRole(role);
    final normalizedStatus = status.trim().toLowerCase();
    final temporaryPassword = generateSecurePassword();
    final appName = 'secondary-${DateTime.now().microsecondsSinceEpoch}';

    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: temporaryPassword,
      );
      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('user').doc(uid).set({
        'user_id': uid,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': normalizedEmail,
        'phone_num': phoneNumber.trim(),
        'address': address.trim(),
        'role': normalizedRole,
        'status': normalizedStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseAuth.instance.sendPasswordResetEmail(email: normalizedEmail);
      await secondaryAuth.signOut();

      return CreatedUserResult(uid: uid, temporaryPassword: temporaryPassword);
    } finally {
      await secondaryApp.delete();
    }
  }

  static Future<Map<String, dynamic>?> getUserProfileByUidOrEmail({
    required String uid,
    required String email,
  }) async {
    final byUid = await FirebaseFirestore.instance.collection('user').doc(uid).get();
    if (byUid.exists) return byUid.data();

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    final byEmail = await FirebaseFirestore.instance
        .collection('user')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byEmail.docs.isEmpty) return null;
    return byEmail.docs.first.data();
  }
}
