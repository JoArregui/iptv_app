import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/main.dart';

void main() {
  testWidgets('shows the playlist input and player empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('URL de la lista M3U'), findsOneWidget);
    expect(
      find.text('Carga una lista M3U para ver tus canales.'),
      findsOneWidget,
    );
    expect(find.byType(Banner), findsNothing);
  });

  testWidgets('player error view fits in a compact player viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 180));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: PlayerErrorView(
              message:
                  'Comprueba que el canal siga activo y que el proveedor permita la conexión.',
              onRetry: _noop,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('No se pudo reproducir el canal'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}
