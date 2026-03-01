import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'user_account_service.dart';

String _firebaseErrorMessage(Object error) {
  if (error is FirebaseException) {
    return error.message ?? error.code;
  }
  return error.toString();
}

class UserManagementView extends StatefulWidget {
  final String currentUserRole;

  const UserManagementView({
    super.key,
    required this.currentUserRole,
  });

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedDocId;
  bool _sortUserIdAscending = true;

  bool get _isAdmin => UserAccountService.isAdminRole(widget.currentUserRole);
  bool get _isEmployee => UserAccountService.isEmployeeRole(widget.currentUserRole);
  bool get _canManageUsers => _isAdmin || _isEmployee;

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  bool _canViewRole(String role) {
    final normalized = UserAccountService.normalizeRole(role);
    if (normalized.isEmpty) return true;
    return UserAccountService.isGrowerRole(normalized);
  }

  bool _matchesSearch(QueryDocumentSnapshot<Map<String, dynamic>> doc, String query) {
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

    return _sortUserIdAscending
        ? aId.compareTo(bId)
        : bId.compareTo(aId);
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

          final rowsPerPage = math.min(
            PaginatedDataTable.defaultRowsPerPage,
            math.max(1, allData.length),
          );

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
                      if (_canManageUsers)
                        OutlinedButton(
                          onPressed: selectedDoc == null ? null : () => _editUser(selectedDoc!),
                          child: const Text('Update'),
                        ),
                      if (_canManageUsers)
                        FilledButton(
                          onPressed: selectedDoc == null
                              ? null
                              : () {
                                  final data = selectedDoc!.data();
                                  final fullName = _safeString(
                                    '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}',
                                    fallback: 'User',
                                  );
                                  _deleteUser(selectedDoc.id, fullName);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
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
                        setState(() => _sortUserIdAscending = !_sortUserIdAscending);
                      },
                      icon: Icon(
                        _sortUserIdAscending ? Icons.arrow_upward : Icons.arrow_downward,
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
                  PaginatedDataTable(
                    header: const Text('Grower Accounts'),
                    columnSpacing: 16,
                    horizontalMargin: 10,
                    headingRowHeight: 48,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('User ID')),
                      DataColumn(label: Text('First Name')),
                      DataColumn(label: Text('Last Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Phone Number')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('History')),
                    ],
                    source: _UsersDataSource(
                      allData,
                      selectedDocId: _selectedDocId,
                      onSelect: (id) {
                        setState(() => _selectedDocId = id);
                      },
                      onViewUser: _openUserDetails,
                    ),
                    rowsPerPage: rowsPerPage,
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

  void _deleteUser(String id, String name) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(rootContext).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firestore.collection('user').doc(id).delete();
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Deleted "$name"')),
                );
              } on Object catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: ${_firebaseErrorMessage(e)}'),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openUserDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final userId = _safeString(data['user_id'], fallback: doc.id);
    final email = _safeString(data['email']);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _UserDetailsPage(
          userDocId: doc.id,
          userId: userId,
          email: email,
        ),
      ),
    );
  }
}

class _UsersDataSource extends DataTableSource {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _data;
  final String? selectedDocId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onViewUser;

  _UsersDataSource(
    this._data, {
    required this.selectedDocId,
    required this.onSelect,
    required this.onViewUser,
  });

  String _safeString(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final doc = _data[index];
    final data = doc.data();

    final firstName = _safeString(data['first_name']);
    final lastName = _safeString(data['last_name']);
    final email = _safeString(data['email']);
    final phoneNumber = _safeString(data['phone_num']);
    final address = _safeString(data['address']);
    final status = _safeString(data['status'], fallback: 'active').toLowerCase();
    final userId = _safeString(data['user_id'], fallback: doc.id);

    return DataRow.byIndex(
      index: index,
      selected: doc.id == selectedDocId,
      onSelectChanged: (selected) => onSelect(selected == true ? doc.id : null),
      cells: [
        DataCell(Text(userId, overflow: TextOverflow.ellipsis)),
        DataCell(Text(firstName, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(lastName)),
        DataCell(Text(email)),
        DataCell(Text(phoneNumber)),
        DataCell(Text(address)),
        DataCell(Text(status)),
        DataCell(
          TextButton(
            onPressed: () => onViewUser(doc),
            child: const Text('View User'),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}

class _UserDetailsPage extends StatelessWidget {
  final String userDocId;
  final String userId;
  final String email;

  const _UserDetailsPage({
    required this.userDocId,
    required this.userId,
    required this.email,
  });

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) return value.toDate().toString();
    if (value is Map || value is List) return value.toString();
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('user').doc(userDocId).snapshots(),
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

          final keys = userData.keys.toList()..sort();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('Field')),
                            DataColumn(label: Text('Value')),
                          ],
                          rows: keys
                              .map(
                                (key) => DataRow(
                                  cells: [
                                    DataCell(Text(key)),
                                    DataCell(Text(_formatValue(userData[key]))),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Tickets',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _UserTicketsTable(userId: userId, email: email),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserTicketsTable extends StatelessWidget {
  final String userId;
  final String email;

  const _UserTicketsTable({
    required this.userId,
    required this.email,
  });

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
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
            columns: const [
              DataColumn(label: Text('Ticket ID')),
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created At')),
            ],
            rows: docs.map((doc) {
              final data = doc.data();
              final createdAt = data['created_at'];
              return DataRow(
                cells: [
                  DataCell(Text(doc.id)),
                  DataCell(Text(_safe(data['subject']))),
                  DataCell(Text(_safe(data['status']))),
                  DataCell(
                    Text(
                      createdAt is Timestamp
                          ? createdAt.toDate().toString()
                          : _safe(createdAt),
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

  const _UserDialog({
    this.document,
    required this.currentUserRole,
  });

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
  bool _isSaving = false;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final data = widget.document?.data() ?? <String, dynamic>{};
    _firstNameCtrl = TextEditingController(text: data['first_name']?.toString() ?? '');
    _lastNameCtrl = TextEditingController(text: data['last_name']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: data['email']?.toString() ?? '');
    _phoneNumberCtrl = TextEditingController(text: data['phone_num']?.toString() ?? '');
    _addressCtrl = TextEditingController(text: data['address']?.toString() ?? '');
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
    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await widget.document!.reference.update({
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'phone_num': _phoneNumberCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'role': 'grower',
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        final result = await UserAccountService.createManagedUser(
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
            content: Text('Grower created. Temporary password: ${result.temporaryPassword}'),
            duration: const Duration(seconds: 12),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving user: ${_firebaseErrorMessage(e)}')),
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
                    child: Text(_isSaving ? 'Saving...' : (_isEditing ? 'Update' : 'Create')),
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
