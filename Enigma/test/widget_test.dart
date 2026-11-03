import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enigma/app.dart';
import 'package:enigma/navigation/student_nav.dart';
import 'package:enigma/core/utils/storage.dart';
import 'package:enigma/core/services/sync_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageUtil.init();
  });

  testWidgets('Enigma App smoke test and UI verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const EnigmaApp(home: StudentNav()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Verify header and core sections exist
    expect(find.text('Sức khỏe của bạn'), findsOneWidget);
    expect(find.text('Cảm xúc hôm nay'), findsOneWidget);
    expect(find.text('Chăm sóc bản thân'), findsOneWidget);

    // Cancel timers
    SyncService.instance.cancelTimers();
    await tester.pump(const Duration(seconds: 1));
  });
}
