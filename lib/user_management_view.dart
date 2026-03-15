import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'grower_details_view.dart';
import 'navigation_provider.dart';
import 'user_account_service.dart';
import 'user_system.dart';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

          QueryDocumentSnapshot<Map<String, dynamic>>? selectedDoc;
          for (final doc in allData) {
            if (doc.id == _selectedDocId) {
              selectedDoc = doc;
              break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _showUserDialog(null),
                        child: const Text('Create'),
                      ),
                      if (_canUpdateOrDeleteGrowers)
                        FilledButton(
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Search',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          ),
                          border: const OutlineInputBorder(),
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
                const SizedBox(height: 8),
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

                      return GrowerCard(
                        userDocId: doc.id,
                        userId: userId,
                        fullName: fullName,
                        email: email,
                        address: address,
                        status: status,
                        role: role,
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

    await UserAccountService.deleteUserAccount(uid: uid);
  }

  void _deleteUser(String id, String name, int? numericUserId) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) {
        final confirmCtrl = TextEditingController();
        bool isDeleting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            final normalizedName = name.trim().toLowerCase();
            final normalizedInput = confirmCtrl.text.trim().toLowerCase();
            final canDelete = normalizedInput == 'delete' ||
                (normalizedName.isNotEmpty && normalizedInput == normalizedName);

            return AlertDialog(
              title: const Text('Confirm Hard Delete'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Type the grower name or "DELETE" to confirm hard deletion.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    decoration: InputDecoration(
                      labelText: 'Confirmation',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onChanged: (_) => setState(() {}),
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
                          setState(() {
                            isDeleting = true;
                            errorText = null;
                          });
                          try {
                            await _hardDeleteUser(
                              uid: id,
                              numericUserId: numericUserId,
                            );
                            if (!rootContext.mounted) return;
                            Navigator.pop(dialogContext);
                            widget.navigationProvider.setIndex(1);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(content: Text('Deleted "$name"')),
                            );
                          } on Object catch (e) {
                            if (!rootContext.mounted) return;
                            setState(() {
                              isDeleting = false;
                              errorText = _firebaseErrorMessage(e);
                            });
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
    final elevation = _isHovered ? 2.4 : 1.2;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Card(
          color: scheme.surface,
          elevation: elevation,
          shadowColor: scheme.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 820;
                  final details = _GrowerDetailsSection(
                    fullName: widget.fullName,
                    email: widget.email,
                    address: widget.address,
                    userId: widget.userId,
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
                    hoverColor: scheme.onSurface.withOpacity(0.04),
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
  });

  final String fullName;
  final String email;
  final String address;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: $userId',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fullName,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          email,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
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
        OutlinedButton(
          onPressed: onView,
          child: const Text('View User'),
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

class _UserDetailsPage extends StatefulWidget {
  final String userDocId;
  final String userId;
  final String email;

  const _UserDetailsPage({
    required this.userDocId,
    required this.userId,
    required this.email,
  });

  @override
  State<_UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<_UserDetailsPage> {
  String _selectedAverageRange = 'Daily';
  String? _selectedSystemId;

  static const List<String> _averageRanges = ['Daily', 'Weekly', 'Monthly'];

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  String _selectedRangeKey() {
    switch (_selectedAverageRange) {
      case 'Weekly':
        return 'weekly';
      case 'Monthly':
        return 'monthly';
      case 'Daily':
      default:
        return 'daily';
    }
  }

  String _formatAverageReading(dynamic value, {String unit = ''}) {
    if (value == null) return '-';
    final text = value.toString().trim();
    if (text.isEmpty) return '-';
    return unit.isEmpty ? text : '$text $unit';
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) return value.toDate().toString();
    if (value is Map || value is List) return value.toString();
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  String _formatFieldName(String key) {
    if (key.trim().isEmpty) return '-';
    final words = key
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1).toLowerCase() : ''}',
        )
        .toList();
    return words.join(' ');
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required Color accentColor,
    required Widget child,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = colorScheme.onPrimary;
    final surfaceColor = colorScheme.surface;
    final bodyColor = Color.alphaBlend(
      accentColor.withOpacity(0.12),
      surfaceColor,
    );
    final borderColor = colorScheme.primary;

    return Card(
      elevation: 1.5,
      color: surfaceColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor,
                    Color.alphaBlend(accentColor.withOpacity(0.2), accentColor),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            Container(
              color: bodyColor,
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableShell({
    required Widget child,
    Color? backgroundColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveBackground = backgroundColor ?? scheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(color: colorScheme.surface),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('user')
              .doc(widget.userDocId)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading user details: ${userSnapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = userSnapshot.data?.data();
            if (userData == null) {
              return const Center(child: Text('User document not found.'));
            }

            return StreamBuilder<List<UserSystem>>(
              stream: UserAccountService.watchUserSystems(widget.userDocId),
              builder: (context, systemsSnapshot) {
                if (systemsSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading systems: ${systemsSnapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }
                if (systemsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final systems = systemsSnapshot.data ?? [];
                if (_selectedSystemId == null && systems.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _selectedSystemId = systems.first.id);
                  });
                }
                final selectedSystem = systems.isEmpty
                    ? null
                    : systems.firstWhere(
                        (system) => system.id == _selectedSystemId,
                        orElse: () => systems.first,
                      );
                final systemLabel = (UserSystem system) =>
                    system.systemName.trim().isNotEmpty
                        ? system.systemName
                        : 'System ${system.id}';

                final averagesMap =
                    _asStringMap(selectedSystem?.sensorAverages);
                final selectedKey = _selectedRangeKey();
                final currentAverages = _asStringMap(averagesMap[selectedKey]);
                final harvestTotals =
                    _asStringMap(selectedSystem?.harvestTotals);
            final onSurface = colorScheme.onSurface;
            final onSurfaceVariant = colorScheme.onSurfaceVariant;
            final sensorAverageRows = <DataRow>[
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Water Temperature (\u00B0C)',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['temp'],
                        unit: '\u00B0C',
                      ),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('pH Level', style: TextStyle(color: onSurface))),
                  DataCell(
                    Text(
                      _formatAverageReading(currentAverages['ph']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Dissolved Oxygen (mg/L)',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatAverageReading(currentAverages['do'], unit: 'mg/L'),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Ammonia (ppm)', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['ammonia'],
                        unit: 'ppm',
                      ),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Salinity (ppt)', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['salinity'],
                        unit: 'ppt',
                      ),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Turbidity (NTU)', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['turbidity'],
                        unit: 'NTU',
                      ),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
            ];

            const hiddenProfileFields = {
              'current_plant_id',
              'current_fish_id',
              'sensor_averages',
              'harvers_totals',
              'harvest_totals',
              'aquaculture_info',
              'plant_info',
              'harvest_info',
              'updated_at',
              'updated_by',
              'user_id',
            };
            final keys =
                userData.keys
                    .where((key) => !hiddenProfileFields.contains(key))
                    .toList()
                  ..sort();

            final extraProfileRows = [
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Participant Join Date',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      'January 15, 2026',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
            ];

            final profileRows = <DataRow>[];
            var hasInsertedExtras = false;
            for (final key in keys) {
              profileRows.add(
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        _formatFieldName(key),
                        style: TextStyle(color: onSurface),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatValue(userData[key]),
                        style: TextStyle(color: onSurface),
                      ),
                    ),
                  ],
                ),
              );
              if (!hasInsertedExtras && key == 'status') {
                profileRows.addAll(extraProfileRows);
                hasInsertedExtras = true;
              }
            }
            if (!hasInsertedExtras) {
              profileRows.addAll(extraProfileRows);
            }

            final profileCard = _buildSectionCard(
              context: context,
              title: 'Profile',
              accentColor: const Color(0xFF1D4ED8),
              child: _buildTableShell(
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Information',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Details',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                  dataTextStyle: TextStyle(color: onSurface),
                  headingTextStyle: TextStyle(color: onSurfaceVariant),
                  rows: profileRows,
                ),
              ),
            );

            final sensorAveragesCard = _buildSectionCard(
              context: context,
              title: 'Average Sensor Readings',
              accentColor: const Color(0xFF0F766E),
              trailing: SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  value: _selectedAverageRange,
                  isExpanded: true,
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surface,
                    hintText: 'Daily',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  items: _averageRanges
                      .map(
                        (range) => DropdownMenuItem<String>(
                          value: range,
                          child: Text(
                            range,
                            style: TextStyle(color: onSurface),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedAverageRange = value);
                  },
                ),
              ),
              child: _buildTableShell(
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Parameter',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Average Reading',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                  dataTextStyle: TextStyle(color: onSurface),
                  headingTextStyle: TextStyle(color: onSurfaceVariant),
                  rows: sensorAverageRows,
                ),
              ),
            );

            final aquacultureInfoRows = [
              DataRow(
                cells: [
                  DataCell(
                    Text('Fish Species', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text('Catfish', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Stocking Date', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text('January 20, 2026', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Initial Stock Quantity',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(Text('50', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Current Population',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(Text('50', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Average Fish Size',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      'Small, Medium, Big',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Survival Rate', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(Text('100%', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Monitoring Schedule',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      'Every 1st of the month',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
            ];

            final aquacultureInfoCard = _buildSectionCard(
              context: context,
              title: 'Aquaculture Information',
              accentColor: const Color(0xFF0369A1),
              child: _buildTableShell(
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Information',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Details',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                  dataTextStyle: TextStyle(color: onSurface),
                  headingTextStyle: TextStyle(color: onSurfaceVariant),
                  rows: aquacultureInfoRows,
                ),
              ),
            );

            final plantInfoRows = [
              DataRow(
                cells: [
                  DataCell(Text('Crop Type', style: TextStyle(color: onSurface))),
                  DataCell(Text('Basil', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Overall Batches', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text(
                      _formatValue(harvestTotals['total_plant_batches']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Crops Per Batch', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(Text('30', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Current Batch', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(Text('Batch 2', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Planting Date', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text('February 3, 2026', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Expected Harvest Date',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text('March 28, 2026', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Growth Stage', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text('Vegetative', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Crop Status', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text('Healthy', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Monitoring Schedule',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text('Every Monday', style: TextStyle(color: onSurface)),
                  ),
                ],
              ),
            ];

            final plantInfoCard = _buildSectionCard(
              context: context,
              title: 'Plant Information',
              accentColor: const Color(0xFF4D7C0F),
              child: _buildTableShell(
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Information',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Details',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                  dataTextStyle: TextStyle(color: onSurface),
                  headingTextStyle: TextStyle(color: onSurfaceVariant),
                  rows: plantInfoRows,
                ),
              ),
            );

            final aquacultureHarvestRows = [
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Total Fish Harvested',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatValue(harvestTotals['total_fish_harvested']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Average Fish Size',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatValue(harvestTotals['average_fish_size']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text('Survival Rate', style: TextStyle(color: onSurface)),
                  ),
                  DataCell(
                    Text(
                      _formatValue(harvestTotals['survival_rate']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
            ];

            final aquacultureHarvestCard = _buildSectionCard(
              context: context,
              title: 'Aquaculture Harvest Information',
              accentColor: const Color(0xFF0C4A6E),
              child: _buildTableShell(
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Information',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Details',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                  dataTextStyle: TextStyle(color: onSurface),
                  headingTextStyle: TextStyle(color: onSurfaceVariant),
                  rows: aquacultureHarvestRows,
                ),
              ),
            );

            final plantHarvestRows = [
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Total Number of Plant Batches',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(Text('5', style: TextStyle(color: onSurface))),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Total Plants Harvested',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatValue(harvestTotals['total_plants_harvested']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      'Average Yield Per Batch',
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatValue(harvestTotals['average_yield_per_batch']),
                      style: TextStyle(color: onSurface),
                    ),
                  ),
                ],
              ),
            ];

            final plantHarvestCard = _buildSectionCard(
              context: context,
              title: 'Plant Harvest Information',
              accentColor: const Color(0xFF3F6212),
              child: _buildTableShell(
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text(
                        'Information',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Details',
                        style: TextStyle(color: onSurfaceVariant),
                      ),
                    ),
                  ],
                  dataTextStyle: TextStyle(color: onSurface),
                  headingTextStyle: TextStyle(color: onSurfaceVariant),
                  rows: plantHarvestRows,
                ),
              ),
            );

            final historyCard = _buildSectionCard(
              context: context,
              title: 'User History',
              accentColor: const Color(0xFFB45309),
              child: _UserHistoryTable(userId: widget.userId),
            );
            final growthProgressLogsCard = _buildSectionCard(
              context: context,
              title: 'Growth Progress Logs',
              accentColor: const Color(0xFF7C3AED),
              child: _UserWeeklyLogsTable(
                userDocId: widget.userDocId,
                systemId: selectedSystem?.id ?? '',
              ),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final showSideBySide = constraints.maxWidth >= 1100;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (systems.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                value: selectedSystem?.id,
                                decoration: const InputDecoration(
                                  labelText: 'System',
                                  border: OutlineInputBorder(),
                                ),
                                items: systems
                                    .map(
                                      (system) => DropdownMenuItem<String>(
                                        value: system.id,
                                        child: Text(systemLabel(system)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _selectedSystemId = value);
                                },
                              ),
                            ),
                          ),
                        ),
                      if (showSideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: profileCard),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  sensorAveragesCard,
                                  const SizedBox(height: 16),
                                  historyCard,
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        profileCard,
                        const SizedBox(height: 16),
                        sensorAveragesCard,
                        const SizedBox(height: 16),
                        historyCard,
                      ],
                      const SizedBox(height: 16),
                      if (showSideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: aquacultureInfoCard),
                            const SizedBox(width: 16),
                            Expanded(child: plantInfoCard),
                          ],
                        )
                      else ...[
                        aquacultureInfoCard,
                        const SizedBox(height: 16),
                        plantInfoCard,
                      ],
                      const SizedBox(height: 16),
                      if (showSideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: aquacultureHarvestCard),
                            const SizedBox(width: 16),
                            Expanded(child: plantHarvestCard),
                          ],
                        )
                      else ...[
                        aquacultureHarvestCard,
                        const SizedBox(height: 16),
                        plantHarvestCard,
                      ],
                      const SizedBox(height: 16),
                      growthProgressLogsCard,
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        context: context,
                        title: 'Support Tickets',
                        accentColor: const Color(0xFF0E7490),
                        child: _UserTicketsTable(
                          userId: widget.userId,
                          email: widget.email,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ),
  ),
);
  }
}

class _UserTicketsTable extends StatelessWidget {
  final String userId;
  final String email;

  const _UserTicketsTable({required this.userId, required this.email});

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('user_id', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error loading support tickets: ${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text(
            'No support tickets found for user_id "$userId"${email.isNotEmpty ? ' ($email)' : ''}.',
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(
                label: Text('Ticket ID', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              DataColumn(
                label: Text('Subject', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              DataColumn(
                label: Text('Status', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              DataColumn(
                label: Text('Created At', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
            dataTextStyle: TextStyle(color: scheme.onSurface),
            headingTextStyle: TextStyle(color: scheme.onSurfaceVariant),
            rows: docs.map((doc) {
              final data = doc.data();
              final createdAt = data['created_at'];
              return DataRow(
                cells: [
                  DataCell(Text(doc.id, style: TextStyle(color: scheme.onSurface))),
                  DataCell(Text(_safe(data['subject']), style: TextStyle(color: scheme.onSurface))),
                  DataCell(Text(_safe(data['status']), style: TextStyle(color: scheme.onSurface))),
                  DataCell(
                    Text(
                      createdAt is Timestamp
                          ? createdAt.toDate().toString()
                          : _safe(createdAt),
                      style: TextStyle(color: scheme.onSurface),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _UserHistoryTable extends StatelessWidget {
  final String userId;

  const _UserHistoryTable({required this.userId});

  String _safeText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDateTime(dynamic value) {
    final dt = _asDateTime(value);
    if (dt == null) return _safeText(value);
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _notificationEvent(Map<String, dynamic> data) {
    return _safeText(
      data['message'] ??
          data['event'] ??
          data['title'] ??
          data['body'] ??
          data['description'],
      fallback: 'Notification',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final numericUserId = int.tryParse(userId);
    final notificationsStream = numericUserId != null
        ? FirebaseFirestore.instance
              .collection('notifications')
              .where('user_id', isEqualTo: numericUserId)
              .snapshots()
        : FirebaseFirestore.instance
              .collection('notifications')
              .where('user_id', isEqualTo: userId)
              .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error loading history: ${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          );
        }

        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            final aDate = _asDateTime(
              aData['created_at'] ?? aData['timestamp'] ?? aData['date'],
            );
            final bDate = _asDateTime(
              bData['created_at'] ?? bData['timestamp'] ?? bData['date'],
            );
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return Text('No notification history found for user_id "$userId".');
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(
                label: Text('Date & Time', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              DataColumn(
                label: Text('Event', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              DataColumn(
                label: Text('User ID', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
            dataTextStyle: TextStyle(color: scheme.onSurface),
            headingTextStyle: TextStyle(color: scheme.onSurfaceVariant),
            rows: docs.map((doc) {
              final data = doc.data();
              final when =
                  data['created_at'] ?? data['timestamp'] ?? data['date'];
              return DataRow(
                cells: [
                  DataCell(
                    Text(_formatDateTime(when), style: TextStyle(color: scheme.onSurface)),
                  ),
                  DataCell(
                    Text(_notificationEvent(data), style: TextStyle(color: scheme.onSurface)),
                  ),
                  DataCell(
                    Text(_safeText(data['user_id'], fallback: userId), style: TextStyle(color: scheme.onSurface)),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _UserWeeklyLogsTable extends StatelessWidget {
  final String userDocId;
  final String systemId;

  const _UserWeeklyLogsTable({
    required this.userDocId,
    required this.systemId,
  });

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value) {
    final dt = _asDateTime(value);
    if (dt == null) return _safe(value);
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (systemId.trim().isEmpty) {
      return const Text('No system selected for weekly logs.');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('user')
          .doc(userDocId)
          .collection('systems')
          .doc(systemId)
          .collection('weekly_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error loading weekly logs: ${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('No weekly growth progress logs found.');
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Date', style: TextStyle(color: scheme.onSurfaceVariant))),
              DataColumn(label: Text('Fish Size (cm)', style: TextStyle(color: scheme.onSurfaceVariant))),
              DataColumn(label: Text('Plant Height (cm)', style: TextStyle(color: scheme.onSurfaceVariant))),
              DataColumn(label: Text('Health Status', style: TextStyle(color: scheme.onSurfaceVariant))),
              DataColumn(label: Text('Notes', style: TextStyle(color: scheme.onSurfaceVariant))),
            ],
            dataTextStyle: TextStyle(color: scheme.onSurface),
            headingTextStyle: TextStyle(color: scheme.onSurfaceVariant),
            rows: docs.map((doc) {
              final data = doc.data();
              return DataRow(
                cells: [
                  DataCell(Text(_formatDate(data['timestamp']), style: TextStyle(color: scheme.onSurface))),
                  DataCell(Text(_formatNumber(data['fish_size_cm']), style: TextStyle(color: scheme.onSurface))),
                  DataCell(Text(_formatNumber(data['plant_height_cm']), style: TextStyle(color: scheme.onSurface))),
                  DataCell(Text(_safe(data['health_status']), style: TextStyle(color: scheme.onSurface))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        _safe(data['notes']),
                        style: TextStyle(color: scheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
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
        final result = await UserAccountService.createManagedUser(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Grower created. Temporary password: ${result.temporaryPassword}',
            ),
            duration: const Duration(seconds: 12),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
                  value: _statusValue,
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
