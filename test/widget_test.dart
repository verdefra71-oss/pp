import 'package:flutter_test/flutter_test.dart';
import 'package:contabilita_familiare/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    final store = FinanceStore();
    await tester.pumpWidget(FamilyFinanceApp(store: store));
    expect(find.text('La mia famiglia'), findsOneWidget);
  });
}
