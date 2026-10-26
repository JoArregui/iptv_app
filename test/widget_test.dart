import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/epg_guide_screen.dart';
import 'package:iptv_app/epg_parser.dart';
import 'package:iptv_app/epg_source_dialog.dart';
import 'package:iptv_app/main.dart';
import 'package:iptv_app/m3u_parser.dart';

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

  testWidgets('EPG source dialog safely disposes its text controller', (
    tester,
  ) async {
    String? selectedSource;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedSource = await showDialog<String>(
                  context: context,
                  builder: (_) => const EpgSourceDialog(),
                );
              },
              child: const Text('Open source dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open source dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://provider.example/guide.xml',
    );
    await tester.tap(find.text('Descargar'));
    await tester.pumpAndSettle();

    expect(selectedSource, 'https://provider.example/guide.xml');
    expect(tester.takeException(), isNull);
  });

  testWidgets('EPG screen explains when the playlist has no guide source', (
    tester,
  ) async {
    final guideState = ValueNotifier(
      const EpgGuideState(
        channels: [],
        programs: [],
        isLoading: false,
        statusMessage: 'No se encontró una fuente XMLTV.',
      ),
    );
    var configureTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EpgGuideScreen(
          state: guideState,
          onConfigureSource: () => configureTapped = true,
        ),
      ),
    );

    expect(find.text('Guía de programación'), findsOneWidget);
    expect(find.text('No se encontró una fuente XMLTV.'), findsOneWidget);
    await tester.tap(find.text('Introducir URL XMLTV'));
    expect(configureTapped, isTrue);

    guideState.value = const EpgGuideState(
      channels: [],
      programs: [],
      isLoading: false,
      statusMessage: 'Descarga XMLTV fallida.',
    );
    await tester.pump();
    expect(find.text('Descarga XMLTV fallida.'), findsOneWidget);
    guideState.dispose();
  });

  testWidgets('EPG screen renders channel schedules without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    final start = DateTime.now().add(const Duration(minutes: 10));
    final guideState = ValueNotifier(
      EpgGuideState(
        channels: const [
          M3U8Entry(
            title: 'Noticias HD',
            url: 'https://example.test/news',
            tvgId: 'NEWS.ES',
          ),
        ],
        programs: [
          EpgProgram(
            channelId: 'news.es',
            title: 'Informativo',
            start: start,
            stop: start.add(const Duration(hours: 1)),
          ),
        ],
        isLoading: false,
        statusMessage: 'Guía actualizada.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: EpgGuideScreen(state: guideState)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Noticias HD'), findsOneWidget);
    expect(find.text('Informativo'), findsOneWidget);
    guideState.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

void _noop() {}
