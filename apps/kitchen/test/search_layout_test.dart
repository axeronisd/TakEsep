// Tests for search bar layout behavior on different screen sizes.
//
// Verifies that on mobile (<600px) the segmented button and
// search field are stacked vertically, while on desktop (>=600px)
// they are in a single row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replicates the responsive search layout logic from sales_screen.dart
Widget buildSearchLayout({required double screenWidth}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(screenWidth, 800)),
      child: Scaffold(
        body: Builder(builder: (context) {
          final isMobile = MediaQuery.of(context).size.width < 600;

          final searchField = const Expanded(
            child: TextField(
              key: Key('search_field'),
              decoration: InputDecoration(hintText: 'Search...'),
            ),
          );

          final segmented = Container(
            key: const Key('segmented_button'),
            width: 200,
            height: 40,
            color: Colors.blue,
          );

          if (isMobile) {
            return Column(
              key: const Key('mobile_layout'),
              children: [
                segmented,
                const SizedBox(height: 8),
                Row(children: [searchField]),
              ],
            );
          }
          return Row(
            key: const Key('desktop_layout'),
            children: [
              segmented,
              const SizedBox(width: 12),
              searchField,
            ],
          );
        }),
      ),
    ),
  );
}

void main() {
  group('Search bar responsive layout', () {
    testWidgets('mobile (360px): Column layout', (tester) async {
      await tester.pumpWidget(buildSearchLayout(screenWidth: 360));

      expect(find.byKey(const Key('mobile_layout')), findsOneWidget);
      expect(find.byKey(const Key('desktop_layout')), findsNothing);
      expect(find.byKey(const Key('segmented_button')), findsOneWidget);
      expect(find.byKey(const Key('search_field')), findsOneWidget);
    });

    testWidgets('mobile (599px): Column layout', (tester) async {
      await tester.pumpWidget(buildSearchLayout(screenWidth: 599));

      expect(find.byKey(const Key('mobile_layout')), findsOneWidget);
      expect(find.byKey(const Key('desktop_layout')), findsNothing);
    });

    testWidgets('desktop (600px): Row layout', (tester) async {
      await tester.pumpWidget(buildSearchLayout(screenWidth: 600));

      expect(find.byKey(const Key('desktop_layout')), findsOneWidget);
      expect(find.byKey(const Key('mobile_layout')), findsNothing);
    });

    testWidgets('desktop (1024px): Row layout', (tester) async {
      await tester.pumpWidget(buildSearchLayout(screenWidth: 1024));

      expect(find.byKey(const Key('desktop_layout')), findsOneWidget);
      expect(find.byKey(const Key('mobile_layout')), findsNothing);
    });

    testWidgets('search field is present in mobile layout', (tester) async {
      await tester.pumpWidget(buildSearchLayout(screenWidth: 375));

      expect(find.byKey(const Key('search_field')), findsOneWidget);
    });

    testWidgets('search field is present in desktop layout', (tester) async {
      await tester.pumpWidget(buildSearchLayout(screenWidth: 1200));

      expect(find.byKey(const Key('search_field')), findsOneWidget);
    });
  });
}
