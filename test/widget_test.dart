import 'package:balloon_designer/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Balloon Designer avvia correttamente',
    (WidgetTester tester) async {
      await tester.pumpWidget(const BalloonDesignerApp());

      expect(find.text('Balloon Designer'), findsOneWidget);
      expect(find.text('NUOVO PROGETTO'), findsOneWidget);
      expect(find.text('I MIEI PROGETTI'), findsOneWidget);
    },
  );
}
