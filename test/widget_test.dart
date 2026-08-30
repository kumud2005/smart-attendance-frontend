import 'package:flutter_test/flutter_test.dart';
import 'package:smart_attendance_frontend/main.dart';

void main() {
  testWidgets('Smart Attendance application loads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Admin Dashboard'), findsOneWidget);
  });
}