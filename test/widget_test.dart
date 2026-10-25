import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_keeper/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the pantry and opens the add-item form', (tester) async {
    await tester.pumpWidget(const PantryApp());
    await tester.pumpAndSettle();

    expect(find.text('小食仓'), findsOneWidget);
    expect(find.text('还没有添加食材'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-item-button')));
    await tester.pumpAndSettle();

    expect(find.text('添加食材'), findsOneWidget);
    expect(find.text('食材名称'), findsOneWidget);
  });
}
