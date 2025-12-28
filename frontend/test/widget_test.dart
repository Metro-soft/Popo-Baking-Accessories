import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/product_management_screen.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ProductProvider())],
        child: const PopoBakingApp(),
      ),
    );

    // Verify that Product Management screen is shown
    expect(find.text('Product Management'), findsOneWidget);
  });
}
