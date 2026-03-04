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

class EmployeeManagementView extends StatefulWidget {
  const EmployeeManagementView({super.key});

  @override
  State<EmployeeManagementView> createState() => _EmployeeManagementViewState();
}

class _EmployeeManagementViewState extends State<EmployeeManagementView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedDocId;
  bool _sortUserIdAscending = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
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

  Future<void> _showEmployeeDialog(
    DocumentSnapshot<Map<String, dynamic>>? document,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EmployeeDialog(document: document),
    );
  }

  Future<void> _deleteEmployee(String id, String name) async {
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
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firestore.collection('employee').doc(id).delete();
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(
                  rootContext,
                ).showSnackBar(SnackBar(content: Text('Deleted "$name"')));
              } on Object catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error deleting employee: ${_firebaseErrorMessage(e)}',
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('employee').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading employees: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _searchCtrl.text.trim();
          final docs = (snapshot.data?.docs ?? [])
              .where((d) => _matchesSearch(d, query))
              .toList();
          docs.sort(_compareUserId);

          QueryDocumentSnapshot<Map<String, dynamic>>? selectedDoc;
          for (final doc in docs) {
            if (doc.id == _selectedDocId) {
              selectedDoc = doc;
              break;
            }
          }

          final rowsPerPage = math.min(
            PaginatedDataTable.defaultRowsPerPage,
            math.max(1, docs.length),
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
                        onPressed: () => _showEmployeeDialog(null),
                        child: const Text('Create'),
                      ),
                      OutlinedButton(
                        onPressed: selectedDoc == null
                            ? null
                            : () => _showEmployeeDialog(selectedDoc),
                        child: const Text('Update'),
                      ),
                      FilledButton(
                        onPressed: selectedDoc == null
                            ? null
                            : () {
                                final data = selectedDoc!.data();
                                final name = _safeString(
                                  '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}',
                                  fallback: 'Employee',
                                );
                                _deleteEmployee(selectedDoc.id, name);
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
                          labelText: 'Search employees',
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
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No employees found.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  PaginatedDataTable(
                    header: const Text('Employees'),
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
                    ],
                    source: _EmployeesDataSource(
                      docs: docs,
                      selectedDocId: _selectedDocId,
                      onSelect: (id) => setState(() => _selectedDocId = id),
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
}

class _EmployeesDataSource extends DataTableSource {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? selectedDocId;
  final ValueChanged<String?> onSelect;

  _EmployeesDataSource({
    required this.docs,
    required this.selectedDocId,
    required this.onSelect,
  });

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  DataRow? getRow(int index) {
    if (index >= docs.length) return null;
    final doc = docs[index];
    final data = doc.data();

    return DataRow.byIndex(
      index: index,
      selected: doc.id == selectedDocId,
      onSelectChanged: (selected) => onSelect(selected == true ? doc.id : null),
      cells: [
        DataCell(Text(_safe(data['user_id'], fallback: doc.id))),
        DataCell(Text(_safe(data['first_name']))),
        DataCell(Text(_safe(data['last_name']))),
        DataCell(Text(_safe(data['email']))),
        DataCell(Text(_safe(data['phone_num']))),
        DataCell(Text(_safe(data['address']))),
        DataCell(Text(_safe(data['status'], fallback: 'active').toLowerCase())),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => docs.length;

  @override
  int get selectedRowCount => 0;
}

class _EmployeeDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? document;

  const _EmployeeDialog({this.document});

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneNumberCtrl;
  late TextEditingController _addressCtrl;
  String _status = 'active';
  bool _isSaving = false;

  bool get _isEditing => widget.document != null;

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
    _status = (data['status']?.toString() ?? 'active').trim().toLowerCase();
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
          'role': 'employee',
          'status': _status,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        final result = await UserAccountService.createManagedUser(
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          email: _emailCtrl.text,
          phoneNumber: _phoneNumberCtrl.text,
          address: _addressCtrl.text,
          role: 'employee',
          status: _status,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Employee created. Temporary password: ${result.temporaryPassword}',
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
          content: Text('Error saving employee: ${_firebaseErrorMessage(e)}'),
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
                _isEditing ? 'Edit Employee' : 'Create Employee',
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
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('active')),
                  DropdownMenuItem(value: 'inactive', child: Text('inactive')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              const SizedBox(height: 24),
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
                    child: Text(
                      _isSaving
                          ? 'Saving...'
                          : (_isEditing ? 'Update' : 'Create'),
                    ),
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
