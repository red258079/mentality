import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enigma/app.dart';

void main() {
  testWidgets('Enigma App smoke test and UI verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const EnigmaApp());
    await tester.pumpAndSettle();

    // Verify header and core sections exist
    expect(find.text('STUDENT WELL-BEING SCORE'), findsOneWidget);
    expect(find.text('HÔM NAY BẠN CẢM THẤY THẾ NÀO?'), findsOneWidget);
    expect(find.text('Thở Hộp 3p'), findsOneWidget);
    expect(find.text('What Next?'), findsOneWidget);
    expect(find.text('Lộ trình 30 ngày'), findsOneWidget);
  });
}
