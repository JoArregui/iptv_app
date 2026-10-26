import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/m3u_parser.dart';

void main() {
  group('parseM3U', () {
    test('parses channel metadata and ignores directives', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-name="Noticias" group-title="General",Otro nombre
#EXTVLCOPT:http-user-agent=Test
https://streams.example/news.m3u8
''';

      expect(parseM3U(playlist), [
        const M3U8Entry(
          title: 'Noticias',
          url: 'https://streams.example/news.m3u8',
          category: 'General',
        ),
      ]);
    });

    test('uses display name and resolves relative stream URLs', () {
      const playlist = '''
#EXTINF:-1,Canal, internacional
../streams/channel.m3u8
''';

      expect(
        parseM3U(
          playlist,
          baseUri: Uri.parse('https://lists.example/playlists/tv/list.m3u'),
        ),
        [
          const M3U8Entry(
            title: 'Canal, internacional',
            url: 'https://lists.example/playlists/streams/channel.m3u8',
          ),
        ],
      );
    });

    test('uses EXTGRP when EXTINF has no group-title', () {
      const playlist = '''
#EXTINF:-1,Canal
#EXTGRP:Deportes
https://streams.example/sport.m3u8
''';

      expect(parseM3U(playlist).single.category, 'Deportes');
    });
  });
}
