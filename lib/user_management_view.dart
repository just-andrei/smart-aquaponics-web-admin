import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';
import 'grower_details_view.dart';
import 'navigation_provider.dart';
import 'user_account_service.dart';

String _firebaseErrorMessage(Object error) {
  if (error is FirebaseException) {
    return error.message ?? error.code;
  }
  return error.toString();
}

class UserManagementView extends StatefulWidget {
  final String currentUserRole;
  final NavigationProvider navigationProvider;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const UserManagementView({
    super.key,
    required this.currentUserRole,
    required this.navigationProvider,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedDocId;
  bool _sortUserIdAscending = true;

  bool get _canUpdateOrDeleteGrowers => true;

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _displayUserId(dynamic value, String docId) {
    if (value is num) return value.toInt().toString();
    final fallback = docId.trim();
    if (fallback.isEmpty) return 'N/A';
    return fallback.length <= 5 ? fallback : fallback.substring(0, 5);
  }

  String _userIdForQuery(dynamic value, String docId) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? docId : text;
  }

  int? _numericUserId(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  String _fullName(Map<String, dynamic> userData) {
    final first = _safeString(userData['first_name']).isNotEmpty
        ? _safeString(userData['first_name'])
        : _safeString(userData['firstName']);
    final last = _safeString(userData['last_name']).isNotEmpty
        ? _safeString(userData['last_name'])
        : _safeString(userData['lastName']);
    final name = '$first $last'.trim();
    return name.isEmpty
        ? _safeString(userData['email'], fallback: 'Unknown User')
        : name;
  }

  bool _canViewRole(String role) {
    final normalized = UserAccountService.normalizeRole(role);
    if (normalized.isEmpty) return true;
    return UserAccountService.isGrowerRole(normalized);
  }

  bool _matchesSearch(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String query,
  ) {
    if (query.isEmpty) return true;
    final data = doc.data();
    final firstName = _safeString(data['first_name']).toLowerCase();
    final lastName = _safeString(data['last_name']).toLowerCase();
    final email = _safeString(data['email']).toLowerCase();
    final phone = _safeString(data['phone_num']).toLowerCase();
    final address = _safeString(data['address']).toLowerCase();
    final q = query.toLowerCase();
    return firstName.contains(q) ||
        lastName.contains(q) ||
        email.contains(q) ||
        phone.contains(q) ||
        address.contains(q);
  }

  int _compareUserId(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aId = _safeString(a.data()['user_id'], fallback: a.id);
    final bId = _safeString(b.data()['user_id'], fallback: b.id);

    final aNum = int.tryParse(aId);
    final bNum = int.tryParse(bId);
    if (aNum != null && bNum != null) {
      return _sortUserIdAscending ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
    }

    return _sortUserIdAscending ? aId.compareTo(bId) : bId.compareTo(aId);
  }

  Widget _overviewChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color color = AquaponicsColors.mossGreen,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF182823)
        : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF28463E)
        : AquaponicsColors.adminBorder;
    final labelColor = isDark
        ? const Color(0xFFA4C0B2)
        : AquaponicsColors.greenhouseSubtext;
    final valueColor = isDark
        ? Colors.white
        : AquaponicsColors.greenhouseText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xCC173128)
        : AquaponicsColors.glassAccent;
    final panelBorderColor = isDark
        ? const Color(0xFF28463E)
        : AquaponicsColors.adminBorder;
    final fieldFillColor = isDark
        ? const Color(0xFF10211C)
        : Colors.white;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('user').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading users: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _searchCtrl.text.trim();
          final allData = (snapshot.data?.docs ?? [])
              .where((doc) => _canViewRole(_safeString(doc.data()['role'])))
              .where((doc) => _matchesSearch(doc, query))
              .toList();
          allData.sort(_compareUserId);
          final activeCount = allData.where((doc) {
            return _safeString(doc.data()['status'], fallback: 'active')
                    .toLowerCase() ==
                'active';
          }).length;

          // Build a count map to detect duplicate user_ids
          final userIdCount = <String, int>{};
          for (final doc in snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
            final uid = _safeString(doc.data()['user_id'], fallback: '');
            if (uid.isNotEmpty) {
              userIdCount[uid] = (userIdCount[uid] ?? 0) + 1;
            }
          }

          QueryDocumentSnapshot<Map<String, dynamic>>? selectedDoc;
          for (final doc in allData) {
            if (doc.id == _selectedDocId) {
              selectedDoc = doc;
              break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: panelBorderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _overviewChip(
                                context: context,
                                icon: Icons.people_alt_rounded,
                                label: 'Growers',
                                value: '${allData.length} registered',
                              ),
                              _overviewChip(
                                context: context,
                                icon: Icons.eco_rounded,
                                label: 'Active',
                                value: '$activeCount operational',
                                color: AquaponicsColors.freshGreen,
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showUserDialog(null),
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text('Create Grower'),
                              ),
                              if (_canUpdateOrDeleteGrowers)
                                FilledButton.icon(
                                  onPressed: selectedDoc == null
                                      ? null
                                      : () {
                                          final data = selectedDoc!.data();
                                          final fullName = _fullName(data);
                                          final numericId = _numericUserId(
                                            selectedDoc.data()['user_id'],
                                          );
                                          _deleteUser(
                                            selectedDoc.id,
                                            fullName,
                                            numericId,
                                          );
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: const Text('Delete Selected'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 380,
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Search growers',
                                hintText: 'Name, email, phone, or address',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                ),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: panelBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AquaponicsColors.mossGreen,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(
                                () => _sortUserIdAscending = !_sortUserIdAscending,
                              );
                            },
                            icon: Icon(
                              _sortUserIdAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                            label: Text(
                              _sortUserIdAscending
                                  ? 'User ID Ascending'
                                  : 'User ID Descending',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (allData.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No users found.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allData.length,
                    itemBuilder: (context, index) {
                      final doc = allData[index];
                      final data = doc.data();
                      final userId = _displayUserId(data['user_id'], doc.id);
                      final userIdForQuery = _userIdForQuery(
                        data['user_id'],
                        doc.id,
                      );
                      final fullName = _fullName(data);
                      final email = _safeString(
                        data['email'],
                        fallback: 'No email provided',
                      );
                      final address = _safeString(
                        data['address'],
                        fallback: 'No address provided',
                      );
                      final status = _safeString(
                        data['status'],
                        fallback: 'active',
                      );
                      final role = _safeString(
                        data['role'],
                        fallback: 'grower',
                      );

                      final rawUserId = _safeString(data['user_id'], fallback: '');
                      final isDuplicate = rawUserId.isNotEmpty &&
                          (userIdCount[rawUserId] ?? 0) > 1;

                      return GrowerCard(
                        userDocId: doc.id,
                        userId: userId,
                        fullName: fullName,
                        email: email,
                        address: address,
                        status: status,
                        role: role,
                        isDuplicate: isDuplicate,
                        onSelect: () {
                          setState(() => _selectedDocId = doc.id);
                        },
                        onView: () => _openUserDetails(doc, userIdForQuery),
                        onEdit: () => _editUser(doc),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showUserDialog(DocumentSnapshot<Map<String, dynamic>>? document) {
    showDialog<void>(
      context: context,
      builder: (context) => _UserDialog(
        document: document,
        currentUserRole: widget.currentUserRole,
      ),
    );
  }

  void _editUser(DocumentSnapshot<Map<String, dynamic>> document) {
    _showUserDialog(document);
  }

  Future<void> _hardDeleteUser({
    required String uid,
    required int? numericUserId,
  }) async {
    final userRef = _firestore.collection('user').doc(uid);
    final refsToDelete = <DocumentReference>[];

    final systemsSnapshot = await userRef.collection('systems').get();
    for (final systemDoc in systemsSnapshot.docs) {
      final weeklySnapshot =
          await systemDoc.reference.collection('weekly_logs').get();
      refsToDelete.addAll(weeklySnapshot.docs.map((doc) => doc.reference));
      refsToDelete.add(systemDoc.reference);
    }

    if (numericUserId != null) {
      final ticketsSnapshot = await _firestore
          .collection('support_tickets')
          .where('user_id', isEqualTo: numericUserId)
          .get();
      refsToDelete.addAll(ticketsSnapshot.docs.map((doc) => doc.reference));
    }

    refsToDelete.add(userRef);

    if (refsToDelete.length > 450) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'too-many-deletes',
        message:
            'Too many related records to delete in a single batch. Please run a server-side cleanup.',
      );
    }

    final batch = _firestore.batch();
    for (final ref in refsToDelete) {
      batch.delete(ref);
    }
    await batch.commit();

    await userRef.delete();
    await UserAccountService.deleteUserAccount(uid: uid);
  }

  void _deleteUser(String id, String name, int? numericUserId) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) {
        final confirmCtrl = TextEditingController();
        bool isDeleting = false;
        bool canDelete = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Hard Delete'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Type "Delete" to confirm hard deletion.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    decoration: const InputDecoration(
                      labelText: "Type 'Delete' to confirm",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        canDelete = value.trim().toLowerCase() == 'delete';
                      });
                    },
                    enabled: !isDeleting,
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(rootContext).colorScheme.error,
                  ),
                  onPressed: !canDelete || isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            await _hardDeleteUser(
                              uid: id,
                              numericUserId: numericUserId,
                            );
                            if (!rootContext.mounted) return;
                            Navigator.pop(dialogContext);
                            widget.navigationProvider.setIndex(1);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Grower and all associated data deleted.',
                                ),
                              ),
                            );
                          } on Object catch (e) {
                            if (!rootContext.mounted) return;
                            setDialogState(() => isDeleting = false);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Delete failed: ${_firebaseErrorMessage(e)}',
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openUserDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String userIdForQuery,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrowerDetailsView(
          userDocId: doc.id,
          userId: userIdForQuery,
          currentUserRole: widget.currentUserRole,
          navigationProvider: widget.navigationProvider,
          onToggleTheme: widget.onToggleTheme,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
}

class GrowerCard extends StatefulWidget {
  final String userDocId;
  final String userId;
  final String fullName;
  final String email;
  final String address;
  final String status;
  final String role;
  final bool isDuplicate;
  final VoidCallback onSelect;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const GrowerCard({
    super.key,
    required this.userDocId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.address,
    required this.status,
    required this.role,
    this.isDuplicate = false,
    required this.onSelect,
    required this.onView,
    required this.onEdit,
  });

  @override
  State<GrowerCard> createState() => _GrowerCardState();
}

class _GrowerCardState extends State<GrowerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF182823) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF28463E)
        : AquaponicsColors.adminBorder;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        child: Card(
          color: cardColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: scheme.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHovered
                    ? AquaponicsColors.mossGreen.withValues(alpha: 0.35)
                    : borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 820;
                  final details = _GrowerDetailsSection(
                    fullName: widget.fullName,
                    email: widget.email,
                    address: widget.address,
                    userId: widget.userId,
                    status: widget.status,
                    isDuplicate: widget.isDuplicate,
                    docId: widget.userDocId,
                  );
                  final statusMetrics = _GrowerStatusSection(
                    userDocId: widget.userDocId,
                  );
                  final actions = _GrowerActionSection(
                    onView: widget.onView,
                    onEdit: widget.onEdit,
                  );

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onSelect,
                    hoverColor: scheme.onSurface.withValues(alpha: 0.04),
                    child: isCompact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              details,
                              const SizedBox(height: 12),
                              statusMetrics,
                              const SizedBox(height: 12),
                              actions,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 4, child: details),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: statusMetrics),
                              const SizedBox(width: 20),
                              SizedBox(width: 180, child: actions),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowerDetailsSection extends StatelessWidget {
  const _GrowerDetailsSection({
    required this.fullName,
    required this.email,
    required this.address,
    required this.userId,
    required this.status,
    required this.isDuplicate,
    required this.docId,
  });

  final String fullName;
  final String email;
  final String address;
  final String userId;
  final String status;
  final bool isDuplicate;
  final String docId;

  Color _avatarColor(String seed) {
    const colors = [
      Color(0xFF1F64D8),
      Color(0xFF0EA5A0),
      Color(0xFF7C3AED),
      Color(0xFFD97706),
      Color(0xFF16A34A),
      Color(0xFFDC2626),
    ];
    final hash = seed.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _badge(
    BuildContext context, {
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = status.toLowerCase() == 'active';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _avatarColor(docId),
          child: Text(
            _initials(fullName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _badge(
                    context,
                    label: isActive ? 'Active' : 'Inactive',
                    backgroundColor: isActive
                        ? (isDark
                            ? const Color(0xFF143D2E)
                            : const Color(0xFFDCFCE7))
                        : (isDark
                            ? const Color(0xFF3A2412)
                            : const Color(0xFFFEF3C7)),
                    textColor: isActive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                  if (isDuplicate)
                    _badge(
                      context,
                      label: 'Duplicate',
                      backgroundColor: isDark
                          ? const Color(0xFF3A1414)
                          : const Color(0xFFFEF2F2),
                      textColor: const Color(0xFFDC2626),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrowerStatusSection extends StatelessWidget {
  const _GrowerStatusSection({
    required this.userDocId,
  });

  final String userDocId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Status',
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _SystemUnitsChip(userDocId: userDocId),
      ],
    );
  }
}

class _SystemUnitsChip extends StatefulWidget {
  final String userDocId;

  const _SystemUnitsChip({required this.userDocId});

  @override
  State<_SystemUnitsChip> createState() => _SystemUnitsChipState();
}

class _SystemUnitsChipState extends State<_SystemUnitsChip> {
  String? _lastSummary;
  bool _lastIsEmpty = true;

  String _summaryText({
    required int total,
    required int active,
    required int unclaimed,
    required int inactive,
  }) {
    if (total == 0) return 'No Units Assigned';

    final parts = <String>[];
    if (active > 0) parts.add('$active Active');
    if (unclaimed > 0) parts.add('$unclaimed Unclaimed');
    if (inactive > 0) parts.add('$inactive Inactive');
    final breakdown = parts.isEmpty ? '' : ' (${parts.join(', ')})';
    return 'Units: $total$breakdown';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userDocId)
          .collection('systems')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ParameterItem(
            label: 'Units',
            value: 'Unavailable',
          );
        }
        final docs = snapshot.data?.docs ?? const [];
        String? summary = _lastSummary;
        var isEmpty = _lastIsEmpty;

        if (snapshot.hasData && docs.isNotEmpty) {
          var active = 0;
          var unclaimed = 0;
          var inactive = 0;
          for (final doc in docs) {
            final data = doc.data();
            final isActive = data['is_system_active'] == true;
            final code = (data['provision_code'] ?? '').toString().trim();
            if (isActive) {
              active += 1;
            } else if (code.isNotEmpty) {
              unclaimed += 1;
            } else {
              inactive += 1;
            }
          }
          final total = docs.length;
          summary = _summaryText(
            total: total,
            active: active,
            unclaimed: unclaimed,
            inactive: inactive,
          );
          isEmpty = total == 0;
          _lastSummary = summary;
          _lastIsEmpty = isEmpty;
        } else if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData) {
          summary = _summaryText(
            total: 0,
            active: 0,
            unclaimed: 0,
            inactive: 0,
          );
          isEmpty = true;
          _lastSummary = summary;
          _lastIsEmpty = isEmpty;
        }

        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
                _lastSummary == null;

        return Container(
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_rounded,
                size: 14,
                color: isEmpty
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: isLoading
                    ? Opacity(
                        opacity: 0.35,
                        child: Text(
                          'Units: 0 (0 Active, 0 Unclaimed)',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Text(
                        summary ?? 'Units: 0',
                        style: textTheme.labelSmall?.copyWith(
                          color: isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParameterItem extends StatelessWidget {
  const _ParameterItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GrowerActionSection extends StatelessWidget {
  const _GrowerActionSection({
    required this.onView,
    required this.onEdit,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('View User'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Update'),
        ),
      ],
    );
  }
}


class _UserDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? document;
  final String currentUserRole;

  const _UserDialog({this.document, required this.currentUserRole});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneNumberCtrl;
  late TextEditingController _addressCtrl;
  late String _statusValue;
  bool _isSaving = false;

  bool get _isEditing => widget.document != null;

  Future<int> _getNextNumericUserId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user')
          .orderBy('user_id', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 1;

      final value = snapshot.docs.first.data()['user_id'];
      if (value is num) return value.toInt() + 1;
    } on FirebaseException catch (e) {
      throw FirebaseException(
        plugin: e.plugin,
        code: e.code,
        message: 'Failed to determine the next user ID.',
      );
    }

    try {
      final numericSnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('user_id', isGreaterThanOrEqualTo: 0)
          .orderBy('user_id', descending: true)
          .limit(1)
          .get();

      if (numericSnapshot.docs.isEmpty) return 1;

      final value = numericSnapshot.docs.first.data()['user_id'];
      if (value is num) return value.toInt() + 1;
    } on FirebaseException {
      return 1;
    }

    return 1;
  }

  @override
  void initState() {
    super.initState();
    final data = widget.document?.data() ?? <String, dynamic>{};
    _firstNameCtrl = TextEditingController(
      text: data['first_name']?.toString() ?? '',
    );
    _lastNameCtrl = TextEditingController(
      text: data['last_name']?.toString() ?? '',
    );
    _emailCtrl = TextEditingController(text: data['email']?.toString() ?? '');
    _phoneNumberCtrl = TextEditingController(
      text: data['phone_num']?.toString() ?? '',
    );
    _addressCtrl = TextEditingController(
      text: data['address']?.toString() ?? '',
    );
    final statusText = data['status']?.toString().trim().toLowerCase();
    _statusValue = (statusText == 'inactive') ? 'inactive' : 'active';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_isEditing) {
        setState(() => _isSaving = true);
        await widget.document!.reference.update({
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'phone_num': _phoneNumberCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'role': 'grower',
          'status': _statusValue,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        final nextUserId = await _getNextNumericUserId();
        if (nextUserId <= 0) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'invalid-argument',
            message: 'Invalid next user ID. Creation aborted.',
          );
        }
        setState(() => _isSaving = true);
        await UserAccountService.createManagedUser(
          userId: nextUserId,
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          email: _emailCtrl.text,
          phoneNumber: _phoneNumberCtrl.text,
          address: _addressCtrl.text,
          role: 'grower',
          status: 'active',
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Grower Created'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (mounted) nav.pop();
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error saving user: ${_firebaseErrorMessage(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit User' : 'Create Grower',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Required';
                  if (!text.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
                maxLines: 2,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _statusValue,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _statusValue = value);
                        },
                ),
              ],
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              if (!_isEditing)
                const Text(
                  'Role will be saved as "grower" and status as "active". A reset email will be sent.',
                  style: TextStyle(fontSize: 12),
                ),
              if (!_isEditing) const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : Text(_isEditing ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
