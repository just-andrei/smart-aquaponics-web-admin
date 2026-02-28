import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aquaponics_colors.dart';

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  // Simulated sensor data
  double temperature = 24.5;
  double ph = 6.8;
  double oxygen = 7.2;
  double salinity = 0.8;
  double ammonia = 0.2;
  double turbidity = 3.0;
  double battery = 82.0;
  int uptime = 99;
  int alertCount = 1;
  String healthStatus = "Excellent";
  String alertDetail = "1 Refill Required";

  // Dispenser levels (percentages)
  double fishFeed = 75;
  double phUp = 60;
  double phDown = 25;

  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => simulateData());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> getDetectedUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (snapshot.exists) {
          // Logic to handle user data
        }
      }
    } catch (e) {
      debugPrint("Firebase error: $e");
    }
  }

  void simulateData() {
    if (!mounted) return;
    setState(() {
      final rand = Random();
      temperature = (temperature + (rand.nextDouble() - 0.5) * 0.3).clamp(18, 32);
      ph = (ph + (rand.nextDouble() - 0.5) * 0.1).clamp(5.0, 9.0);
      oxygen = (oxygen + (rand.nextDouble() - 0.5) * 0.2).clamp(3.0, 12.0);
      salinity = (salinity + (rand.nextDouble() - 0.5) * 0.05).clamp(0, 3);
      ammonia = (ammonia + (rand.nextDouble() - 0.5) * 0.05).clamp(0, 1);
      turbidity = (turbidity + (rand.nextDouble() - 0.5) * 0.5).clamp(0, 10);
      battery = (battery + (rand.nextDouble() - 0.5) * 1.5).clamp(0, 100);
      uptime = 99 + rand.nextInt(2);
      
      fishFeed = (fishFeed - rand.nextDouble() * 0.3).clamp(0, 100);
      phUp = (phUp - rand.nextDouble() * 0.3).clamp(0, 100);
      phDown = (phDown - rand.nextDouble() * 0.3).clamp(0, 100);

      List<String> refillAlerts = [];
      if (phDown < 20) refillAlerts.add('pH Down');
      if (phUp < 30) refillAlerts.add('pH Up');
      if (fishFeed < 20) refillAlerts.add('Fish Feed');
      alertCount = refillAlerts.length;
      healthStatus = alertCount > 0 ? 'Warning' : 'Excellent';
      alertDetail = alertCount == 0
          ? 'All dispensers at good level'
          : refillAlerts.length == 1
              ? '${refillAlerts[0]} dispenser needs refill'
              : '${refillAlerts.length} dispensers need refill';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _summaryCard(
                icon: Icons.group,
                label: 'Total Users',
                value: '124',
                detail: '+12 this week',
                color: AquaponicsColors.primaryAccent,
                context: context,
              ),
              _summaryCard(
                icon: Icons.grid_view,
                label: 'Active Systems',
                value: '89',
                detail: '98% Operational',
                color: AquaponicsColors.statusSafe,
                context: context,
              ),
              _summaryCard(
                icon: Icons.battery_full,
                label: 'Power Status',
                value: '${battery.toStringAsFixed(0)}%',
                detail: 'Discharging',
                color: AquaponicsColors.primaryAccent,
                context: context,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Water Quality Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statCard(Icons.thermostat, 'Temperature', '${temperature.toStringAsFixed(1)}°C', '22–28°C', _getStatus(temperature, 22, 28, 18, 32), context),
              _statCard(Icons.science, 'pH Level', ph.toStringAsFixed(1), '6.5–7.5', _getStatus(ph, 6.5, 7.5, 6.0, 8.0), context),
              _statCard(Icons.bubble_chart, 'Dissolved Oxygen', '${oxygen.toStringAsFixed(1)} mg/L', '> 5.0 mg/L', _getStatus(oxygen, 5.0, 10, 4.0, 12), context),
              _statCard(Icons.opacity, 'Salinity', '${salinity.toStringAsFixed(1)} ppt', '0–2 ppt', _getStatus(salinity, 0, 2, -0.5, 3), context),
              _statCard(Icons.biotech, 'Ammonia', '${ammonia.toStringAsFixed(2)} mg/L', '< 0.5 mg/L', _getStatus(ammonia, 0, 0.5, 0.5, 1), context),
              _statCard(Icons.water_drop, 'Turbidity', '${turbidity.toStringAsFixed(1)} NTU', '< 5 NTU', _getStatus(turbidity, 0, 5, 5, 10), context),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Dispenser Levels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dispenserCard('Fish Feed', fishFeed, 10, 'kg', context),
              _dispenserCard('pH Up', phUp, 5, 'L', context),
              _dispenserCard('pH Down', phDown, 5, 'L', context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    required Color color,
    required BuildContext context,
  }) {
    return Container(
      width: 280, // Flexible width for Wrap
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: Theme.of(context).textTheme.labelMedium),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, String range, String status, BuildContext context) {
    Color color = status == 'safe'
        ? AquaponicsColors.statusSafe
        : (status == 'warning' ? AquaponicsColors.statusWarning : AquaponicsColors.statusDanger);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AquaponicsColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(range, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _dispenserCard(String title, double level, double capacity, String unit, BuildContext context) {
    Color color = level > 50 ? AquaponicsColors.statusSafe : (level > 20 ? AquaponicsColors.statusWarning : AquaponicsColors.statusDanger);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AquaponicsColors.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: level / 100,
            backgroundColor: AquaponicsColors.subtleBorder,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${level.toStringAsFixed(0)}% Remaining', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _getStatus(double value, double min, double max, double wMin, double wMax) {
    if (value >= min && value <= max) return 'safe';
    if (value >= wMin && value <= wMax) return 'warning';
    return 'danger';
  }
}