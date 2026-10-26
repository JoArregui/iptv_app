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

    test('reads an XMLTV source and tvg-id from playlist metadata', () {
      const playlist = '''
#EXTM3U url-tvg="../guide.xml"
#EXTINF:-1 tvg-id="news.es" tvg-name="Noticias" group-title="General",Noticiero
https://streams.example/news
''';
      final parsed = parseM3UPlaylist(
        playlist,
        baseUri: Uri.parse('https://lists.example/playlists/list.m3u'),
      );

      expect(parsed.epgUri, Uri.parse('https://lists.example/guide.xml'));
      expect(parsed.channels.single.tvgId, 'news.es');
    });

    test('derives the XMLTV endpoint from a standard Xtream playlist URL', () {
      final source = Uri.parse(
        'https://provider.example:8443/get.php?username=user&password=secret&type=m3u_plus',
      );

      expect(
        inferXtreamEpgUri(source),
        Uri.parse(
          'https://provider.example:8443/xmltv.php?username=user&password=secret',
        ),
      );
    });

    test('recognizes the configured Solanaflix Xtream host', () {
      final source = Uri.parse(
        'https://572369.solanaflix.com/playlist.m3u?username=user&password=secret',
      );

      expect(
        inferXtreamEpgUri(source),
        Uri.parse(
          'https://572369.solanaflix.com/xmltv.php?username=user&password=secret',
        ),
      );
    });

    test('does not infer an EPG endpoint without Xtream credentials', () {
      expect(
        inferXtreamEpgUri(Uri.parse('https://provider.example/list.m3u')),
        isNull,
      );
    });
  });
}
