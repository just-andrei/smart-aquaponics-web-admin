import 'package:flutter/material.dart';
import 'aquaponics_colors.dart';

class SupportTicketsView extends StatelessWidget {
  const SupportTicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          color: Theme.of(context).cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: index % 2 == 0 ? AquaponicsColors.statusWarning : AquaponicsColors.statusSafe,
              child: Icon(index % 2 == 0 ? Icons.priority_high : Icons.check, color: Colors.white),
            ),
            title: Text('Ticket #${1000 + index} - System Issue'),
            subtitle: Text('Reported by User ${index + 1} • 2 hours ago'),
            trailing: Chip(
              label: Text(index % 2 == 0 ? 'Open' : 'Resolved'),
              backgroundColor: index % 2 == 0 ? AquaponicsColors.statusWarning.withOpacity(0.2) : AquaponicsColors.statusSafe.withOpacity(0.2),
              labelStyle: TextStyle(color: index % 2 == 0 ? AquaponicsColors.statusWarning : AquaponicsColors.statusSafe),
            ),
            onTap: () {},
          ),
        );
      },
    );
  }
}