import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_relay/features/map/destination_route_sheet.dart';

void main() {
  testWidgets('collects a destination and offers motorcycle app handoff', (
    tester,
  ) async {
    DestinationPlanRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                request = await DestinationRouteSheet.show(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destination-field')),
      'Matlock Bath',
    );
    await tester.tap(find.byKey(const Key('add-route-stop')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('route-stop-field-0')),
      'Bakewell',
    );
    await tester.tap(find.byKey(const Key('destination-handoff-field')));
    await tester.pumpAndSettle();

    expect(find.text('Calimoto'), findsOneWidget);
    expect(find.text('MyRoute-app'), findsOneWidget);

    await tester.tap(find.text('MyRoute-app'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('plan-destination-button')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('plan-destination-button')));
    await tester.pumpAndSettle();

    expect(request?.query, 'Matlock Bath');
    expect(request?.stopQueries, const ['Bakewell']);
    expect(request?.handoffTarget?.name, 'myRouteApp');
  });

  testWidgets('restores an edited request and allows stops to be reordered', (
    tester,
  ) async {
    DestinationPlanRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                request = await DestinationRouteSheet.show(
                  context,
                  initialRequest: const DestinationPlanRequest(
                    startQuery: 'Start',
                    stopQueries: ['First', 'Second'],
                    query: 'Finish',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);

    await tester.tap(find.byKey(const Key('move-route-stop-down-0')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('plan-destination-button')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('plan-destination-button')));
    await tester.pumpAndSettle();

    expect(request?.stopQueries, const ['Second', 'First']);
  });
}
