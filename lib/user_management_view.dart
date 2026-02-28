import 'package:flutter/material.dart';
import 'aquaponics_colors.dart';

class UserManagementView extends StatelessWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'User Accounts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DataTable(
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: List.generate(5, (index) {
                  final status = index % 2 == 0 ? 'Active' : 'Inactive';
                  return DataRow(cells: [
                    DataCell(Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AquaponicsColors.primaryAccent.withOpacity(0.2),
                          child: Text('U${index + 1}', style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Text('User ${index + 1}'),
                      ],
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'Active' ? AquaponicsColors.statusSafe.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(status, style: TextStyle(
                        color: status == 'Active' ? AquaponicsColors.statusSafe : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      )),
                    )),
                    DataCell(Row(
                      children: [
                        IconButton(icon: const Icon(Icons.check, color: AquaponicsColors.statusSafe), onPressed: () {}, tooltip: 'Activate'),
                        IconButton(icon: const Icon(Icons.block, color: AquaponicsColors.statusWarning), onPressed: () {}, tooltip: 'Deactivate'),
                        IconButton(icon: const Icon(Icons.refresh, color: AquaponicsColors.primaryAccent), onPressed: () {}, tooltip: 'Reset'),
                      ],
                    )),
                  ]);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}