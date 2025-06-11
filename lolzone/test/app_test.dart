import 'package:flutter_test/flutter_test.dart';
import 'package:lolzone/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app has a title.
    expect(find.text('LOLZone'), findsOneWidget);
  });

  testWidgets('Meme feed loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the meme feed is visible.
    expect(find.byType(MemeFeed), findsOneWidget);
  });

  testWidgets('Meme editor opens successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Find and tap the meme editor button.
    final editorButton = find.byIcon(Icons.edit);
    await tester.tap(editorButton);
    await tester.pumpAndSettle();

    // Verify that the meme editor is visible.
    expect(find.byType(MemeEditor), findsOneWidget);
  });
}
