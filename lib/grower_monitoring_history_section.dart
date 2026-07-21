import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'aquaponics_colors.dart';

class GrowerSystemMonitoringSection extends StatefulWidget {
  const GrowerSystemMonitoringSection({
    super.key,
    required this.userCollection,
    required this.userDocId,
    required this.growerUid,
    required this.growerName,
    required this.growerEmail,
    required this.systemId,
    required this.systemLabel,
    required this.fallbackHardwareUid,
    required this.fallbackIsSystemActive,
  });

  final String userCollection;
  final String userDocId;
  final String growerUid;
  final String growerName;
  final String growerEmail;
  final String systemId;
  final String systemLabel;
  final String fallbackHardwareUid;
  final bool fallbackIsSystemActive;

  @override
  State<GrowerSystemMonitoringSection> createState() =>
      _GrowerSystemMonitoringSectionState();
}

class _GrowerSystemMonitoringSectionState
    extends State<GrowerSystemMonitoringSection> {
  bool _isLoggingAlerts = false;

  Future<void> _logCurrentAlerts(
    BuildContext context,
    List<_DetectedAlertPreview> previews,
    String hardwareUid,
  ) async {
    if (_isLoggingAlerts || previews.isEmpty) return;

    setState(() => _isLoggingAlerts = true);
    var saved = 0;
    var skipped = 0;

    try {
      final alerts = FirebaseFirestore.instance.collection('environmental_alerts');

      for (final preview in previews) {
        final docRef = alerts.doc(preview.dedupeKey);
        final existingDoc = await docRef.get();
        if (existingDoc.exists) {
          final existingData = existingDoc.data() ?? const <String, dynamic>{};
          final existingStatus = _normalizedAlertStatus(existingData['status']);
          if (existingStatus != 'resolved') {
            skipped++;
            continue;
          }
        }

        await docRef.set({
          'growerUid': widget.growerUid,
          'growerName': widget.growerName,
          'growerEmail': widget.growerEmail,
          'systemId': widget.systemId,
          'systemName': widget.systemLabel,
          'hardwareUid': hardwareUid,
          'parameter': preview.parameter,
          'value': preview.rawValue,
          'severity': preview.severity,
          'message': preview.message,
          'status': 'new',
          'source': 'web-monitoring-manual',
          'dedupeKey': preview.dedupeKey,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'acknowledgedAt': null,
          'resolvedAt': null,
        });
        saved++;
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $saved alert(s). Skipped $skipped duplicate(s).'),
        ),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert logging failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert logging failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingAlerts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemStream = FirebaseFirestore.instance
        .collection(widget.userCollection)
        .doc(widget.userDocId)
        .collection('systems')
        .doc(widget.systemId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: systemStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MonitoringStateView(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load monitoring data',
            message: 'Firestore returned an error: ${snapshot.error}',
            isError: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _MonitoringLoadingView();
        }

        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final sensorAverages = _readMap(
          data['sensor_averages'] ?? data['sensorAverages'],
        );
        final monitoringData = _preferredMonitoringMap(sensorAverages, data);
        final metrics = _MonitoringMetrics(
          ph: _readDouble(monitoringData, const [
            'ph',
            'pH',
            'avg_ph',
            'average_ph',
          ]),
          waterTemperature: _readDouble(monitoringData, const [
            'temp',
            'temperature',
            'water_temp',
            'waterTemperature',
            'avg_temp',
          ]),
          dissolvedOxygen: _readDouble(monitoringData, const [
            'do',
            'dissolved_oxygen',
            'dissolvedOxygen',
            'avg_do',
          ]),
          turbidity: _readDouble(monitoringData, const [
            'turbidity',
            'avg_turbidity',
          ]),
          humidity: _readDouble(monitoringData, const [
            'humidity',
            'avg_humidity',
          ]),
        );

        final status = _computeStatus(metrics);
        final latestTimestamp = _readDateTimeFromMap(data, const [
          'updatedAt',
          'updated_at',
          'createdAt',
          'created_at',
          'timestamp',
        ]);
        final hardwareUid = _safeString(
          data['hardware_uid'] ?? data['hardwareUid'],
          fallback: widget.fallbackHardwareUid,
        );
        final isSystemActive = _readBool(
          data['is_system_active'] ?? data['isSystemActive'],
          fallback: widget.fallbackIsSystemActive,
        );
        final previews = _buildAlertPreviews(
          growerUid: widget.growerUid,
          systemId: widget.systemId,
          metrics: metrics,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonitoringHeader(
                systemLabel: widget.systemLabel,
                hardwareUid: hardwareUid,
                latestTimestamp: latestTimestamp,
                status: status,
                isSystemActive: isSystemActive,
              ),
              const SizedBox(height: 14),
              _MonitoringMetricWrap(metrics: metrics),
              const SizedBox(height: 14),
              _AlertPreviewSection(
                previews: previews,
                isSaving: _isLoggingAlerts,
                onLogAlerts: previews.isEmpty
                    ? null
                    : () => _logCurrentAlerts(context, previews, hardwareUid),
              ),
              const SizedBox(height: 14),
              _SavedAlertsSection(
                growerUid: widget.growerUid,
                systemId: widget.systemId,
              ),
              const SizedBox(height: 14),
              _WeeklyHistorySection(
                userCollection: widget.userCollection,
                userDocId: widget.userDocId,
                systemId: widget.systemId,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonitoringHeader extends StatelessWidget {
  const _MonitoringHeader({
    required this.systemLabel,
    required this.hardwareUid,
    required this.latestTimestamp,
    required this.status,
    required this.isSystemActive,
  });

  final String systemLabel;
  final String hardwareUid;
  final DateTime? latestTimestamp;
  final _MonitoringStatus status;
  final bool isSystemActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final statusForeground = _foregroundFor(status.color);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 580,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monitoring & History',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                systemLabel,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hardware UID: ${hardwareUid.isEmpty ? 'Pending' : hardwareUid}',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Latest monitoring: ${_formatDateTime(latestTimestamp)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: status.label,
              background: status.color,
              foreground: statusForeground,
            ),
            _StatusChip(
              label: isSystemActive ? 'Claimed' : 'Unclaimed',
              background: isSystemActive
                  ? AquaponicsColors.adminInfo.withValues(alpha: 0.14)
                  : scheme.surfaceContainerHighest,
              foreground: isSystemActive
                  ? AquaponicsColors.adminInfo
                  : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }
}

class _MonitoringMetricWrap extends StatelessWidget {
  const _MonitoringMetricWrap({required this.metrics});

  final _MonitoringMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'pH', value: _formatReading(metrics.ph)),
        _MetricCard(
          label: 'Water Temp',
          value: _formatReading(metrics.waterTemperature, suffix: ' C'),
        ),
        _MetricCard(
          label: 'Dissolved Oxygen',
          value: _formatReading(metrics.dissolvedOxygen, suffix: ' mg/L'),
        ),
        _MetricCard(
          label: 'Turbidity',
          value: _formatReading(metrics.turbidity),
        ),
        _MetricCard(
          label: 'Humidity',
          value: _formatReading(metrics.humidity, suffix: ' %'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPreviewSection extends StatelessWidget {
  const _AlertPreviewSection({
    required this.previews,
    required this.isSaving,
    required this.onLogAlerts,
  });

  final List<_DetectedAlertPreview> previews;
  final bool isSaving;
  final VoidCallback? onLogAlerts;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current alert previews', style: titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Warning and Critical conditions are previewed here. Firestore writes only happen when an admin clicks Log Current Alerts.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: isSaving ? null : onLogAlerts,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notification_add_rounded),
              label: Text(isSaving ? 'Logging...' : 'Log Current Alerts'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (previews.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              'No current Warning or Critical alerts detected for this system.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...previews.map(
            (preview) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 540,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview.parameter,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${preview.formattedValue} | ${preview.message}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
                    label: preview.severityLabel,
                    background: preview.severityColor,
                    foreground: _foregroundFor(preview.severityColor),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedAlertsSection extends StatelessWidget {
  const _SavedAlertsSection({
    required this.growerUid,
    required this.systemId,
  });

  final String growerUid;
  final String systemId;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('environmental_alerts')
        .where('growerUid', isEqualTo: growerUid)
        .where('systemId', isEqualTo: systemId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved alerts', style: titleStyle),
              const SizedBox(height: 10),
              Text(
                'Saved alerts could not be loaded: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved alerts', style: titleStyle),
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 4),
            ],
          );
        }

        final docs = (snapshot.data?.docs ?? const [])
            .toList()
          ..sort((a, b) {
            final aTime = _readDateTime(a.data()['createdAt']);
            final bTime = _readDateTime(b.data()['createdAt']);
            final aValue =
                aTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bValue =
                bTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bValue.compareTo(aValue);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved alerts', style: titleStyle),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              Text(
                'No saved alerts for this system yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SavedAlertCard(document: doc),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SavedAlertCard extends StatefulWidget {
  const _SavedAlertCard({required this.document});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  State<_SavedAlertCard> createState() => _SavedAlertCardState();
}

class _SavedAlertCardState extends State<_SavedAlertCard> {
  bool _isUpdatingStatus = false;

  Future<void> _updateStatus(String? value) async {
    if (value == null || _isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final update = <String, dynamic>{
        'status': value,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (value == 'acknowledged') {
        update['acknowledgedAt'] = FieldValue.serverTimestamp();
      }
      if (value == 'resolved') {
        update['resolvedAt'] = FieldValue.serverTimestamp();
      }
      if (value == 'new') {
        update['acknowledgedAt'] = null;
        update['resolvedAt'] = null;
      }

      await widget.document.reference.update(update);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert status updated to $value.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();
    final status = _normalizedAlertStatus(data['status']);
    final severity = _normalizedSeverity(data['severity']);
    final severityColor = severity == 'critical'
        ? AquaponicsColors.statusDanger
        : AquaponicsColors.statusWarning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: severity,
                    background: severityColor,
                    foreground: _foregroundFor(severityColor),
                  ),
                  _StatusChip(
                    label: status,
                    background: _alertStatusColor(status),
                    foreground: _foregroundFor(_alertStatusColor(status)),
                  ),
                ],
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Alert Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const ['new', 'acknowledged', 'resolved']
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: _isUpdatingStatus ? null : _updateStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _safeString(data['parameter'], fallback: 'Unknown parameter'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _safeString(data['message'], fallback: 'No message'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Value: ${_safeString(data['value'], fallback: 'No value')} | Created: ${_formatDateTime(_readDateTimeFromMap(data, const ['createdAt']))}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_isUpdatingStatus) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    );
  }
}

class _WeeklyHistorySection extends StatelessWidget {
  const _WeeklyHistorySection({
    required this.userCollection,
    required this.userDocId,
    required this.systemId,
  });

  final String userCollection;
  final String userDocId;
  final String systemId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(userCollection)
          .doc(userDocId)
          .collection('systems')
          .doc(systemId)
          .collection('weekly_logs')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent weekly history', style: titleStyle),
              const SizedBox(height: 10),
              Text(
                'Weekly log summary could not be loaded: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent weekly history', style: titleStyle),
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 4),
            ],
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent weekly history', style: titleStyle),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              Text(
                'No weekly logs available for this system yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final status = _safeString(
                  data['health_status'],
                  fallback: 'No status',
                );
                final notes = _safeString(
                  data['notes'],
                  fallback: 'No notes recorded.',
                );
                final timestamp = _readDateTimeFromMap(data, const [
                  'timestamp',
                  'updatedAt',
                  'updated_at',
                  'createdAt',
                  'created_at',
                ]);
                final metrics = _weeklyMetricSummary(data);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _formatDateTime(timestamp),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _weeklyStatusColor(status)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _weeklyStatusColor(status),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notes,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      if (metrics.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          metrics,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _MonitoringLoadingView extends StatelessWidget {
  const _MonitoringLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monitoring & History',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(minHeight: 4),
        ],
      ),
    );
  }
}

class _MonitoringStateView extends StatelessWidget {
  const _MonitoringStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: isError ? scheme.error : AquaponicsColors.adminInfo,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MonitoringMetrics {
  const _MonitoringMetrics({
    this.ph,
    this.waterTemperature,
    this.dissolvedOxygen,
    this.turbidity,
    this.humidity,
  });

  final double? ph;
  final double? waterTemperature;
  final double? dissolvedOxygen;
  final double? turbidity;
  final double? humidity;
}

class _MonitoringStatus {
  const _MonitoringStatus({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class _DetectedAlertPreview {
  const _DetectedAlertPreview({
    required this.parameter,
    required this.formattedValue,
    required this.rawValue,
    required this.severity,
    required this.message,
    required this.dedupeKey,
  });

  final String parameter;
  final String formattedValue;
  final num rawValue;
  final String severity;
  final String message;
  final String dedupeKey;

  String get severityLabel => severity == 'critical' ? 'Critical' : 'Warning';

  Color get severityColor => severity == 'critical'
      ? AquaponicsColors.statusDanger
      : AquaponicsColors.statusWarning;
}

Map<String, dynamic> _preferredMonitoringMap(
  Map<String, dynamic> sensorAverages,
  Map<String, dynamic> root,
) {
  final daily = _readMap(sensorAverages['daily']);
  if (daily.isNotEmpty) return daily;
  final weekly = _readMap(sensorAverages['weekly']);
  if (weekly.isNotEmpty) return weekly;
  final monthly = _readMap(sensorAverages['monthly']);
  if (monthly.isNotEmpty) return monthly;
  if (sensorAverages.isNotEmpty) return sensorAverages;
  return root;
}

_MonitoringStatus _computeStatus(_MonitoringMetrics metrics) {
  var available = 0;
  var warning = 0;
  var critical = 0;

  void assessRange(
    double? value, {
    required double normalMin,
    required double normalMax,
    required double warningMin,
    required double warningMax,
  }) {
    if (value == null) return;
    available++;
    if (value < warningMin || value > warningMax) {
      critical++;
    } else if (value < normalMin || value > normalMax) {
      warning++;
    }
  }

  void assessMin(
    double? value, {
    required double normalMin,
    required double warningMin,
  }) {
    if (value == null) return;
    available++;
    if (value < warningMin) {
      critical++;
    } else if (value < normalMin) {
      warning++;
    }
  }

  void assessMax(
    double? value, {
    required double normalMax,
    required double warningMax,
  }) {
    if (value == null) return;
    available++;
    if (value > warningMax) {
      critical++;
    } else if (value > normalMax) {
      warning++;
    }
  }

  assessRange(
    metrics.ph,
    normalMin: 6.5,
    normalMax: 8.0,
    warningMin: 6.0,
    warningMax: 8.5,
  );
  assessRange(
    metrics.waterTemperature,
    normalMin: 24.0,
    normalMax: 30.0,
    warningMin: 20.0,
    warningMax: 32.0,
  );
  assessMin(
    metrics.dissolvedOxygen,
    normalMin: 5.0,
    warningMin: 3.5,
  );
  assessMax(
    metrics.turbidity,
    normalMax: 15.0,
    warningMax: 30.0,
  );
  assessRange(
    metrics.humidity,
    normalMin: 45.0,
    normalMax: 80.0,
    warningMin: 35.0,
    warningMax: 90.0,
  );

  if (available == 0) {
    return const _MonitoringStatus(
      label: 'No data',
      color: Color(0xFF94A3B8),
    );
  }
  if (critical > 0) {
    return const _MonitoringStatus(
      label: 'Critical',
      color: AquaponicsColors.statusDanger,
    );
  }
  if (warning > 0) {
    return const _MonitoringStatus(
      label: 'Warning',
      color: AquaponicsColors.statusWarning,
    );
  }
  return const _MonitoringStatus(
    label: 'Normal',
    color: AquaponicsColors.statusSafe,
  );
}

List<_DetectedAlertPreview> _buildAlertPreviews({
  required String growerUid,
  required String systemId,
  required _MonitoringMetrics metrics,
}) {
  final alerts = <_DetectedAlertPreview>[];

  void addRangeAlert({
    required String parameter,
    required double? value,
    required double normalMin,
    required double normalMax,
    required double warningMin,
    required double warningMax,
    required String suffix,
  }) {
    if (value == null) return;
    String? severity;
    if (value < warningMin || value > warningMax) {
      severity = 'critical';
    } else if (value < normalMin || value > normalMax) {
      severity = 'warning';
    }
    if (severity == null) return;

    alerts.add(
      _DetectedAlertPreview(
        parameter: parameter,
        formattedValue: '${value.toStringAsFixed(1)}$suffix',
        rawValue: value,
        severity: severity,
        message:
            '$parameter is outside the safe range of $normalMin to $normalMax$suffix.',
        dedupeKey: _dedupeKey(growerUid, systemId, parameter, severity),
      ),
    );
  }

  void addMinAlert({
    required String parameter,
    required double? value,
    required double normalMin,
    required double warningMin,
    required String suffix,
  }) {
    if (value == null) return;
    String? severity;
    if (value < warningMin) {
      severity = 'critical';
    } else if (value < normalMin) {
      severity = 'warning';
    }
    if (severity == null) return;

    alerts.add(
      _DetectedAlertPreview(
        parameter: parameter,
        formattedValue: '${value.toStringAsFixed(1)}$suffix',
        rawValue: value,
        severity: severity,
        message: '$parameter dropped below the minimum safe level of $normalMin$suffix.',
        dedupeKey: _dedupeKey(growerUid, systemId, parameter, severity),
      ),
    );
  }

  void addMaxAlert({
    required String parameter,
    required double? value,
    required double normalMax,
    required double warningMax,
    required String suffix,
  }) {
    if (value == null) return;
    String? severity;
    if (value > warningMax) {
      severity = 'critical';
    } else if (value > normalMax) {
      severity = 'warning';
    }
    if (severity == null) return;

    alerts.add(
      _DetectedAlertPreview(
        parameter: parameter,
        formattedValue: '${value.toStringAsFixed(1)}$suffix',
        rawValue: value,
        severity: severity,
        message: '$parameter exceeded the maximum safe level of $normalMax$suffix.',
        dedupeKey: _dedupeKey(growerUid, systemId, parameter, severity),
      ),
    );
  }

  addRangeAlert(
    parameter: 'pH',
    value: metrics.ph,
    normalMin: 6.5,
    normalMax: 8.0,
    warningMin: 6.0,
    warningMax: 8.5,
    suffix: '',
  );
  addRangeAlert(
    parameter: 'water_temperature',
    value: metrics.waterTemperature,
    normalMin: 24.0,
    normalMax: 30.0,
    warningMin: 20.0,
    warningMax: 32.0,
    suffix: ' C',
  );
  addMinAlert(
    parameter: 'dissolved_oxygen',
    value: metrics.dissolvedOxygen,
    normalMin: 5.0,
    warningMin: 3.5,
    suffix: ' mg/L',
  );
  addMaxAlert(
    parameter: 'turbidity',
    value: metrics.turbidity,
    normalMax: 15.0,
    warningMax: 30.0,
    suffix: '',
  );
  addRangeAlert(
    parameter: 'humidity',
    value: metrics.humidity,
    normalMin: 45.0,
    normalMax: 80.0,
    warningMin: 35.0,
    warningMax: 90.0,
    suffix: ' %',
  );

  return alerts;
}

String _dedupeKey(
  String growerUid,
  String systemId,
  String parameter,
  String severity,
) {
  return '${growerUid}_${systemId}_${parameter.toLowerCase()}_${severity.toLowerCase()}';
}

String _safeString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

double? _readDouble(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _readDateTimeFromMap(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final parsed = _readDateTime(data[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

String _formatReading(double? value, {String suffix = ''}) {
  if (value == null) return 'No data';
  return '${value.toStringAsFixed(1)}$suffix';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'No timestamp';
  return DateFormat('MMM d, y - h:mm a').format(value.toLocal());
}

Color _foregroundFor(Color background) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  return brightness == Brightness.dark ? Colors.white : const Color(0xFF10211C);
}

String _weeklyMetricSummary(Map<String, dynamic> data) {
  final parts = <String>[];
  final ph = _readDouble(data, const ['ph', 'pH', 'avg_ph']);
  final temp = _readDouble(data, const ['temp', 'temperature', 'water_temp']);
  final dissolvedOxygen = _readDouble(
    data,
    const ['do', 'dissolved_oxygen', 'dissolvedOxygen'],
  );
  final turbidity = _readDouble(data, const ['turbidity']);
  final humidity = _readDouble(data, const ['humidity']);

  if (ph != null) parts.add('pH ${ph.toStringAsFixed(1)}');
  if (temp != null) parts.add('Temp ${temp.toStringAsFixed(1)} C');
  if (dissolvedOxygen != null) {
    parts.add('DO ${dissolvedOxygen.toStringAsFixed(1)} mg/L');
  }
  if (turbidity != null) parts.add('Turbidity ${turbidity.toStringAsFixed(1)}');
  if (humidity != null) parts.add('Humidity ${humidity.toStringAsFixed(1)}%');

  return parts.join(' | ');
}

Color _weeklyStatusColor(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('critical') || normalized.contains('unhealthy')) {
    return AquaponicsColors.statusDanger;
  }
  if (normalized.contains('healthy') || normalized.contains('good')) {
    return AquaponicsColors.statusSafe;
  }
  return AquaponicsColors.statusWarning;
}

String _normalizedAlertStatus(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'acknowledged' || text == 'resolved') return text;
  return 'new';
}

String _normalizedSeverity(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'critical' ? 'critical' : 'warning';
}

Color _alertStatusColor(String status) {
  switch (status) {
    case 'resolved':
      return AquaponicsColors.statusSafe;
    case 'acknowledged':
      return AquaponicsColors.adminInfo;
    default:
      return AquaponicsColors.statusWarning;
  }
}
