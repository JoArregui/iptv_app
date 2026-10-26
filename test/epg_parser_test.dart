import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/epg_parser.dart';

void main() {
  group('parseXmltv', () {
    test('parses programme metadata and converts the timezone to UTC', () {
      const xmltv = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20261026133000 +0100" stop="20261026143000 +0100" channel="news.es">
    <title lang="es">Informativo</title>
    <desc>Noticias del día</desc>
  </programme>
</tv>
''';

      final programs = parseXmltv(xmltv);

      expect(programs, hasLength(1));
      expect(programs.single.channelId, 'news.es');
      expect(programs.single.title, 'Informativo');
      expect(programs.single.start, DateTime.utc(2026, 10, 26, 12, 30));
      expect(programs.single.stop, DateTime.utc(2026, 10, 26, 13, 30));
      expect(programs.single.description, 'Noticias del día');
    });

    test('ignores invalid programme records', () {
      const xmltv = '''
<tv>
  <programme start="invalid" stop="invalid" channel="news.es">
    <title>Invalid</title>
  </programme>
</tv>
''';

      expect(parseXmltv(xmltv), isEmpty);
    });
  });
}
