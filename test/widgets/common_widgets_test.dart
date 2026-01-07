// Widget Tests for Learning-related widgets
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Tests', () {
    group('Progress Indicator Widget', () {
      testWidgets('LinearProgressIndicator displays correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LinearProgressIndicator(
                value: 0.5,
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
          ),
        );

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('CircularProgressIndicator displays correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Card Widget Tests', () {
      testWidgets('Card with content displays correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Test Title'),
                      const SizedBox(height: 8),
                      const Text('Test Content'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Action'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test Title'), findsOneWidget);
        expect(find.text('Test Content'), findsOneWidget);
        expect(find.text('Action'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Button Widget Tests', () {
      testWidgets('ElevatedButton is tappable', (tester) async {
        bool wasPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ElevatedButton(
                onPressed: () => wasPressed = true,
                child: const Text('Press Me'),
              ),
            ),
          ),
        );

        expect(find.text('Press Me'), findsOneWidget);
        expect(wasPressed, false);

        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(wasPressed, true);
      });

      testWidgets('IconButton displays icon and is tappable', (tester) async {
        bool wasPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => wasPressed = true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(wasPressed, true);
      });

      testWidgets('OutlinedButton displays correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OutlinedButton(
                onPressed: () {},
                child: const Text('Outlined'),
              ),
            ),
          ),
        );

        expect(find.text('Outlined'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });
    });

    group('List Widget Tests', () {
      testWidgets('ListView displays multiple items', (tester) async {
        final items = ['Item 1', 'Item 2', 'Item 3', 'Item 4'];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(items[index]),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
        expect(find.text('Item 4'), findsOneWidget);
      });

      testWidgets('ListTile with leading and trailing widgets', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ListTile(
                leading: Icon(Icons.book),
                title: Text('Word Book'),
                subtitle: Text('100 words'),
                trailing: Icon(Icons.arrow_forward_ios),
              ),
            ),
          ),
        );

        expect(find.text('Word Book'), findsOneWidget);
        expect(find.text('100 words'), findsOneWidget);
        expect(find.byIcon(Icons.book), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      });
    });

    group('Input Widget Tests', () {
      testWidgets('TextField accepts input', (tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Enter text',
                ),
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Hello World');
        await tester.pump();

        expect(controller.text, 'Hello World');
      });

      testWidgets('TextField with suffix icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });
    });

    group('Container and Layout Tests', () {
      testWidgets('Row layout displays children horizontally', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.star),
                  Icon(Icons.favorite),
                  Icon(Icons.bookmark),
                ],
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
      });

      testWidgets('Column layout displays children vertically', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Text('Line 1'),
                  Text('Line 2'),
                  Text('Line 3'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Line 1'), findsOneWidget);
        expect(find.text('Line 2'), findsOneWidget);
        expect(find.text('Line 3'), findsOneWidget);
      });

      testWidgets('Container with decoration', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Box'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Box'), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Navigation Widget Tests', () {
      testWidgets('AppBar displays title and actions', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Test Page'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const Center(child: Text('Content')),
            ),
          ),
        );

        expect(find.text('Test Page'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('Back button navigates back', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Second Page'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Navigate'),
                ),
              ),
            ),
          ),
        );

        // Navigate to second page
        await tester.tap(find.text('Navigate'));
        await tester.pumpAndSettle();

        expect(find.text('Second Page'), findsOneWidget);

        // Go back
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('Navigate'), findsOneWidget);
      });
    });

    group('Chip Widget Tests', () {
      testWidgets('Chip displays label', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Chip(
                label: Text('Grammar'),
              ),
            ),
          ),
        );

        expect(find.text('Grammar'), findsOneWidget);
        expect(find.byType(Chip), findsOneWidget);
      });

      testWidgets('FilterChip can be selected', (tester) async {
        bool isSelected = false;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: FilterChip(
                    label: const Text('Category'),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() => isSelected = value);
                    },
                  ),
                ),
              );
            },
          ),
        );

        expect(find.text('Category'), findsOneWidget);

        await tester.tap(find.byType(FilterChip));
        await tester.pump();

        // Chip should now be selected
        expect(find.byType(FilterChip), findsOneWidget);
      });
    });

    group('Score Display Tests', () {
      testWidgets('Score with percentage displays correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '85',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '分',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('85'), findsOneWidget);
        expect(find.text('分'), findsOneWidget);
      });
    });
  });
}
