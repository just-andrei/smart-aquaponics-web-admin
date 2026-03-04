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

  const UserManagementView({super.key, required this.currentUserRole});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedDocId;
  bool _sortUserIdAscending = true;

  bool get _isAdmin => UserAccountService.isAdminRole(widget.currentUserRole);
  bool get _canUpdateOrDeleteGrowers => _isAdmin;

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
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
                      if (_canUpdateOrDeleteGrowers)
                        OutlinedButton(
                          onPressed: selectedDoc == null
                              ? null
                              : () => _editUser(selectedDoc!),
                          child: const Text('Update'),
                        ),
                      if (_canUpdateOrDeleteGrowers)
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
                ScaffoldMessenger.of(
                  rootContext,
                ).showSnackBar(SnackBar(content: Text('Deleted "$name"')));
              } on Object catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error deleting user: ${_firebaseErrorMessage(e)}',
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

  void _openUserDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final userId = _safeString(data['user_id'], fallback: doc.id);
    final email = _safeString(data['email']);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _UserDetailsPage(userDocId: doc.id, userId: userId, email: email),
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
    final status = _safeString(
      data['status'],
      fallback: 'active',
    ).toLowerCase();
    final userId = _safeString(data['user_id'], fallback: doc.id);

    return DataRow.byIndex(
      index: index,
      selected: doc.id == selectedDocId,
      onSelectChanged: (selected) => onSelect(selected == true ? doc.id : null),
      cells: [
        DataCell(Text(userId, overflow: TextOverflow.ellipsis)),
        DataCell(
          Text(firstName, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
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
    final titleColor = Colors.white;
    final bodyColor = accentColor.withOpacity(0.06);
    final borderColor = accentColor.withOpacity(0.24);

    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.86)],
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
    );
  }

  Widget _buildTableShell({
    required Widget child,
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E2E0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F5),
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F6F5), Color(0xFFEAF1EF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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

            final averagesMap = _asStringMap(userData['sensor_averages']);
            final selectedKey = _selectedRangeKey();
            final currentAverages = _asStringMap(averagesMap[selectedKey]);
            final sensorAverageRows = <DataRow>[
              DataRow(
                cells: [
                  const DataCell(Text('Water Temperature (\u00B0C)')),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['temp'],
                        unit: '\u00B0C',
                      ),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('pH Level')),
                  DataCell(Text(_formatAverageReading(currentAverages['ph']))),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Dissolved Oxygen (mg/L)')),
                  DataCell(
                    Text(
                      _formatAverageReading(currentAverages['do'], unit: 'mg/L'),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Ammonia (ppm)')),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['ammonia'],
                        unit: 'ppm',
                      ),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Salinity (ppt)')),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['salinity'],
                        unit: 'ppt',
                      ),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Turbidity (NTU)')),
                  DataCell(
                    Text(
                      _formatAverageReading(
                        currentAverages['turbidity'],
                        unit: 'NTU',
                      ),
                    ),
                  ),
                ],
              ),
            ];

            const hiddenProfileFields = {
              'active_plant_id',
              'active_fish_id',
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

            const extraProfileRows = [
              DataRow(
                cells: [
                  DataCell(Text('Participant Join Date')),
                  DataCell(Text('January 15, 2026')),
                ],
              ),
            ];

            final profileRows = <DataRow>[];
            var hasInsertedExtras = false;
            for (final key in keys) {
              profileRows.add(
                DataRow(
                  cells: [
                    DataCell(Text(_formatFieldName(key))),
                    DataCell(Text(_formatValue(userData[key]))),
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
                  columns: const [
                    DataColumn(label: Text('Information')),
                    DataColumn(label: Text('Details')),
                  ],
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
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Daily',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
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
                          child: Text(range),
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
                  columns: const [
                    DataColumn(label: Text('Parameter')),
                    DataColumn(label: Text('Average Reading')),
                  ],
                  rows: sensorAverageRows,
                ),
              ),
            );

            const aquacultureInfoRows = [
              DataRow(
                cells: [
                  DataCell(Text('Fish Species')),
                  DataCell(Text('Catfish')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Stocking Date')),
                  DataCell(Text('January 20, 2026')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Initial Stock Quantity')),
                  DataCell(Text('50')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Current Population')),
                  DataCell(Text('50')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Average Fish Size')),
                  DataCell(Text('Small, Medium, Big')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Survival Rate')),
                  DataCell(Text('100%')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Monitoring Schedule')),
                  DataCell(Text('Every 1st of the month')),
                ],
              ),
            ];

            final aquacultureInfoCard = _buildSectionCard(
              context: context,
              title: 'Aquaculture Information',
              accentColor: const Color(0xFF0369A1),
              child: _buildTableShell(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Information')),
                    DataColumn(label: Text('Details')),
                  ],
                  rows: aquacultureInfoRows,
                ),
              ),
            );

            const plantInfoRows = [
              DataRow(
                cells: [DataCell(Text('Crop Type')), DataCell(Text('Basil'))],
              ),
              DataRow(
                cells: [DataCell(Text('Overall Batches')), DataCell(Text('5'))],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Crops Per Batch')),
                  DataCell(Text('30')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Current Batch')),
                  DataCell(Text('Batch 2')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Planting Date')),
                  DataCell(Text('February 3, 2026')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Expected Harvest Date')),
                  DataCell(Text('March 28, 2026')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Growth Stage')),
                  DataCell(Text('Vegetative')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Crop Status')),
                  DataCell(Text('Healthy')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Monitoring Schedule')),
                  DataCell(Text('Every Monday')),
                ],
              ),
            ];

            final plantInfoCard = _buildSectionCard(
              context: context,
              title: 'Plant Information',
              accentColor: const Color(0xFF4D7C0F),
              child: _buildTableShell(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Information')),
                    DataColumn(label: Text('Details')),
                  ],
                  rows: plantInfoRows,
                ),
              ),
            );

            const aquacultureHarvestRows = [
              DataRow(
                cells: [
                  DataCell(Text('Total Fish Harvested')),
                  DataCell(Text('45')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Average Fish Size')),
                  DataCell(Text('Big')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Survival Rate')),
                  DataCell(Text('90.0%')),
                ],
              ),
            ];

            final aquacultureHarvestCard = _buildSectionCard(
              context: context,
              title: 'Aquaculture Harvest Information',
              accentColor: const Color(0xFF0C4A6E),
              child: _buildTableShell(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Information')),
                    DataColumn(label: Text('Details')),
                  ],
                  rows: aquacultureHarvestRows,
                ),
              ),
            );

            const plantHarvestRows = [
              DataRow(
                cells: [
                  DataCell(Text('Total Number of Plant Batches')),
                  DataCell(Text('5')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Total Plants Harvested')),
                  DataCell(Text('150')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('Average Yield Per Batch')),
                  DataCell(Text('30 plants')),
                ],
              ),
            ];

            final plantHarvestCard = _buildSectionCard(
              context: context,
              title: 'Plant Harvest Information',
              accentColor: const Color(0xFF3F6212),
              child: _buildTableShell(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Information')),
                    DataColumn(label: Text('Details')),
                  ],
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

            return LayoutBuilder(
              builder: (context, constraints) {
                final showSideBySide = constraints.maxWidth >= 1100;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
            columns: const [
              DataColumn(label: Text('Date & Time')),
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('User ID')),
            ],
            rows: docs.map((doc) {
              final data = doc.data();
              final when =
                  data['created_at'] ?? data['timestamp'] ?? data['date'];
              return DataRow(
                cells: [
                  DataCell(Text(_formatDateTime(when))),
                  DataCell(Text(_notificationEvent(data))),
                  DataCell(Text(_safeText(data['user_id'], fallback: userId))),
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
