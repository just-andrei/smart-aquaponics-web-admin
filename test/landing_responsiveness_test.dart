import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_aquaponics_web_application/main.dart';

void main() {
  final sizes = <Size>[
    const Size(1440, 900),
    const Size(1024, 768),
    const Size(768, 1024),
    const Size(390, 844),
    const Size(360, 640),
  ];

  for (final size in sizes) {
    testWidgets('landing page fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = flutterErrors.add;
      addTearDown(() {
        FlutterError.onError = previousOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(themeMode: ThemeMode.light, onThemeChanged: (_) {}),
        ),
      );
      await tester.pump();

      final layoutExceptions = flutterErrors.where((error) {
        final text = error.exceptionAsString();
        return text.contains('overflowed') ||
            text.contains('RenderFlex') ||
            text.contains('A RenderBox overflowed');
      }).toList();

      final diagnostics = layoutExceptions
          .map((error) {
            final details = <String>[
              error.exceptionAsString(),
              if (error.context != null) error.context.toString(),
              if (error.informationCollector != null)
                ...error.informationCollector!().map((node) => node.toString()),
            ];
            return details.join('\n');
          })
          .join('\n\n');

      expect(layoutExceptions, isEmpty, reason: diagnostics);
      expect(find.text('Admin Login'), findsNothing);
      expect(
        find.text('For Bulacan growers, fishponds, and learning farms'),
        findsNothing,
      );
      expect(find.text('For Bulacan Growers'), findsNothing);
      expect(find.text('Greenhouse Control Center'), findsNothing);
      expect(find.text('Request Demo'), findsWidgets);
    });
  }
}
