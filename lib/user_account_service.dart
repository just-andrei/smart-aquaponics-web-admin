import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'user_system.dart';

class CreatedUserResult {
  final String uid;
  final String temporaryPassword;

  const CreatedUserResult({required this.uid, required this.temporaryPassword});
}

class UserProfileRecord {
  final String collection;
  final String uid;
  final Map<String, dynamic> data;

  const UserProfileRecord({
    required this.collection,
    required this.uid,
    required this.data,
  });
}

class UserSessionAccess {
  final String uid;
  final String email;
  final String role;
  final String status;
  final String sourceCollection;
  final Map<String, dynamic>? profileData;

  const UserSessionAccess({
    required this.uid,
    required this.email,
    required this.role,
    required this.status,
    required this.sourceCollection,
    required this.profileData,
  });

  bool get isAuthenticated => uid.trim().isNotEmpty;

  bool get isActive => status == 'active';

  bool get isAdmin => UserAccountService.isAdminRole(role);

  bool get isGrower => UserAccountService.isGrowerRole(role);
}

class UserAccountService {
  UserAccountService._();

  static const List<String> roleCollectionsInPriority = [
    'users',
    'admin',
    'user',
  ];

  static const List<String> growerCollectionsInPriority = ['user', 'users'];

  static String normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'manager') return 'admin';
    if (normalized == 'user') return 'grower';
    return normalized;
  }

  static bool isAdminRole(String role) => normalizeRole(role) == 'admin';

  static bool isGrowerRole(String role) => normalizeRole(role) == 'grower';

  static String fallbackRoleForCollection(String collection) {
    switch (collection.trim().toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'user':
        return 'grower';
      default:
        return 'unknown';
    }
  }

  static String normalizeStatus({dynamic status, dynamic isActive}) {
    if (isActive is bool) {
      return isActive ? 'active' : 'inactive';
    }

    final normalized = status?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return 'active';
    if (normalized == 'active') return 'active';
    if (normalized == 'inactive' ||
        normalized == 'disabled' ||
        normalized == 'blocked' ||
        normalized == 'suspended') {
      return 'inactive';
    }
    return normalized;
  }

  static String collectionForRole(String role) {
    final normalizedRole = normalizeRole(role);
    if (normalizedRole == 'admin') return 'admin';
    return 'user';
  }

  static Future<String> resolveGrowerCollectionName() async {
    for (final collection in growerCollectionsInPriority) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) return collection;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return 'user';
  }

  static Future<UserSessionAccess> resolveSessionAccessForUser(
    User user,
  ) async {
    final email = (user.email ?? '').trim().toLowerCase();
    final profileRecord = await getProfileByUidOrEmail(
      uid: user.uid,
      email: email,
    );
    final profile = profileRecord?.data;
    final fallbackRole = profileRecord == null
        ? 'unknown'
        : fallbackRoleForCollection(profileRecord.collection);

    final role = normalizeRole((profile?['role'] ?? fallbackRole).toString());
    final status = normalizeStatus(
      status: profile?['status'],
      isActive: profile?['isActive'],
    );

    return UserSessionAccess(
      uid: user.uid,
      email: email,
      role: role,
      status: status,
      sourceCollection: profileRecord?.collection ?? '',
      profileData: profile,
    );
  }

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
    required int userId,
    String? targetCollection,
    String phoneNumber = '',
    String address = '',
    String status = 'active',
  }) async {
    if (userId <= 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid user ID. A positive integer is required.',
      );
    }
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedRole = normalizeRole(role);
    final normalizedStatus = status.trim().toLowerCase();
    final temporaryPassword = generateSecurePassword();
    final appName = 'secondary-${DateTime.now().microsecondsSinceEpoch}';
    final numericUserId = int.parse(userId.toString());

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
      final createdUser = credential.user!;
      try {
        final uid = createdUser.uid;
        final collection =
            targetCollection != null && targetCollection.trim().isNotEmpty
            ? targetCollection.trim()
            : collectionForRole(normalizedRole);
        final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
        await FirebaseFirestore.instance.collection(collection).doc(uid).set({
          'user_id': numericUserId,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'name': fullName,
          'email': normalizedEmail,
          'phone_num': phoneNumber.trim(),
          'address': address.trim(),
          'role': normalizedRole,
          'status': normalizedStatus,
          'isActive': normalizedStatus == 'active',
          'updated_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: normalizedEmail,
        );

        return CreatedUserResult(
          uid: uid,
          temporaryPassword: temporaryPassword,
        );
      } on Object {
        // Keep Auth and Firestore in sync if profile creation fails.
        await createdUser.delete();
        rethrow;
      } finally {
        await secondaryAuth.signOut();
      }
    } finally {
      await secondaryApp.delete();
    }
  }

  static Future<UserProfileRecord?> getProfileByUid(String uid) async {
    for (final collection in roleCollectionsInPriority) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          return UserProfileRecord(
            collection: collection,
            uid: uid,
            data: doc.data()!,
          );
        }
      } on FirebaseException catch (e) {
        // Some rulesets deny cross-collection reads. Skip denied collections.
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return null;
  }

  static Future<UserProfileRecord?> getProfileByUidOrEmail({
    required String uid,
    required String email,
  }) async {
    final byUid = await getProfileByUid(uid);
    if (byUid != null) return byUid;

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    for (final collection in roleCollectionsInPriority) {
      try {
        final byEmail = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final doc = byEmail.docs.first;
          return UserProfileRecord(
            collection: collection,
            uid: doc.id,
            data: doc.data(),
          );
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserProfileByUidOrEmail({
    required String uid,
    required String email,
  }) async {
    final profile = await getProfileByUidOrEmail(uid: uid, email: email);
    return profile?.data;
  }

  static Future<String?> resolveEmailForIdentifier(String identifier) async {
    final normalized = identifier.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final numericId = int.tryParse(normalized);

    for (final collection in roleCollectionsInPriority) {
      try {
        // 1) Direct UID/doc-id lookup.
        final byUid = await FirebaseFirestore.instance
            .collection(collection)
            .doc(normalized)
            .get();
        if (byUid.exists && byUid.data() != null) {
          final email = (byUid.data()!['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }

        // 2) Username lookup.
        final byUsername = await FirebaseFirestore.instance
            .collection(collection)
            .where('username', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byUsername.docs.isNotEmpty) {
          final email = (byUsername.docs.first.data()['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }

        // 3) Numeric/logical user_id lookup.
        final byUserId = await FirebaseFirestore.instance
            .collection(collection)
            .where('user_id', isEqualTo: numericId ?? normalized)
            .limit(1)
            .get();
        if (byUserId.docs.isNotEmpty) {
          final email = (byUserId.docs.first.data()['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }

        // 4) Email lookup fallback (if input is already an email).
        final byEmail = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final email = (byEmail.docs.first.data()['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return null;
  }

  static Future<String?> resolveEmailForUsername(String username) {
    // Backward-compatible alias.
    return resolveEmailForIdentifier(username);
  }

  static Future<void> deleteManagedUser({
    required String uid,
    required String collection,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedCollection = collection.trim().toLowerCase();
    if (normalizedUid.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_functions',
        code: 'invalid-argument',
        message: 'Missing UID for deletion.',
      );
    }
    if (normalizedCollection.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_functions',
        code: 'invalid-argument',
        message: 'Missing collection for deletion.',
      );
    }

    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('deleteManagedUser');

    await callable.call(<String, dynamic>{
      'uid': normalizedUid,
      'collection': normalizedCollection,
    });
  }

  static Future<void> deleteUserAccount({required String uid}) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_functions',
        code: 'invalid-argument',
        message: 'Missing UID for deletion.',
      );
    }

    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('deleteUserAccount');

    await callable.call(<String, dynamic>{'uid': normalizedUid});
  }

  static Stream<List<UserSystem>> watchUserSystems(
    String uid, {
    String userCollection = 'user',
  }) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return const Stream<List<UserSystem>>.empty();
    }
    return FirebaseFirestore.instance
        .collection(userCollection)
        .doc(normalizedUid)
        .collection('systems')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(UserSystem.fromFirestore).toList(),
        );
  }

  static Future<void> updateSystemData(
    String uid,
    String systemId,
    Map<String, dynamic> data, {
    String userCollection = 'user',
  }) {
    return FirebaseFirestore.instance
        .collection(userCollection)
        .doc(uid)
        .collection('systems')
        .doc(systemId)
        .update(data);
  }
}
