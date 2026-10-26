class M3U8Entry {
  final String? title;
  final String url;
  final String? category;
  final String? tvgId;

  const M3U8Entry({this.title, required this.url, this.category, this.tvgId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! M3U8Entry) return false;
    return url == other.url &&
        title == other.title &&
        category == other.category &&
        tvgId == other.tvgId;
  }

  @override
  int get hashCode => Object.hash(url, title, category, tvgId);

  @override
  String toString() =>
      'M3U8Entry(title: $title, url: $url, category: $category, tvgId: $tvgId)';
}

class M3UPlaylist {
  final List<M3U8Entry> channels;
  final Uri? epgUri;

  const M3UPlaylist({required this.channels, this.epgUri});
}

Uri? inferXtreamEpgUri(Uri playlistUri) {
  final query = playlistUri.queryParameters;
  final username = query['username'];
  final password = query['password'];
  final isKnownXtreamHost =
      playlistUri.host.toLowerCase() == '572369.solanaflix.com';
  final isGetEndpoint =
      playlistUri.pathSegments.isNotEmpty &&
      playlistUri.pathSegments.last.toLowerCase() == 'get.php';
  final isXtreamPlaylist =
      isGetEndpoint ||
      isKnownXtreamHost ||
      (query['type']?.toLowerCase().startsWith('m3u') == true);

  if (!isXtreamPlaylist ||
      username == null ||
      username.isEmpty ||
      password == null ||
      password.isEmpty) {
    return null;
  }

  final pathSegments = [...playlistUri.pathSegments];
  if (isGetEndpoint) {
    pathSegments.removeLast();
  } else if (isKnownXtreamHost) {
    pathSegments.clear();
  }
  pathSegments.add('xmltv.php');

  return playlistUri.replace(
    pathSegments: pathSegments,
    queryParameters: {'username': username, 'password': password},
  );
}

List<M3U8Entry> parseM3U(String content, {Uri? baseUri}) {
  return parseM3UPlaylist(content, baseUri: baseUri).channels;
}

M3UPlaylist parseM3UPlaylist(String content, {Uri? baseUri}) {
  final entries = <M3U8Entry>[];
  String? pendingTitle;
  String? pendingCategory;
  String? pendingTvgId;
  Uri? epgUri;

  for (final line in content.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.startsWith('#EXTM3U')) {
      final epgUrl =
          _attribute(trimmed, 'url-tvg') ??
          _attribute(trimmed, 'x-tvg-url') ??
          _attribute(trimmed, 'tvg-url') ??
          _attribute(trimmed, 'epg-url');
      epgUri ??= _resolveHttpUri(epgUrl, baseUri);
      continue;
    }

    if (trimmed.startsWith('#EXTINF')) {
      pendingTitle = _attribute(trimmed, 'tvg-name') ?? _displayName(trimmed);
      pendingCategory = _attribute(trimmed, 'group-title');
      pendingTvgId = _attribute(trimmed, 'tvg-id');
      continue;
    }

    if (trimmed.startsWith('#EXTGRP:')) {
      if (pendingTitle != null) {
        pendingCategory = trimmed.substring('#EXTGRP:'.length).trim();
      }
      continue;
    }

    if (trimmed.startsWith('#') || pendingTitle == null) continue;

    final streamUri = _resolveUri(trimmed, baseUri);
    if (streamUri != null) {
      entries.add(
        M3U8Entry(
          title: pendingTitle.isEmpty ? null : pendingTitle,
          url: streamUri.toString(),
          category: pendingCategory?.isEmpty == true ? null : pendingCategory,
          tvgId: pendingTvgId?.isEmpty == true ? null : pendingTvgId,
        ),
      );
    }
    pendingTitle = null;
    pendingCategory = null;
    pendingTvgId = null;
  }

  return M3UPlaylist(channels: entries, epgUri: epgUri);
}

Uri? _resolveHttpUri(String? value, Uri? baseUri) {
  final resolved = _resolveUri(value, baseUri);
  if (resolved == null ||
      !resolved.hasAuthority ||
      !{'http', 'https'}.contains(resolved.scheme.toLowerCase())) {
    return null;
  }
  return resolved;
}

Uri? _resolveUri(String? value, Uri? baseUri) {
  if (value == null || value.trim().isEmpty) return null;

  try {
    final uri = Uri.parse(value.trim());
    return uri.hasScheme || baseUri == null ? uri : baseUri.resolveUri(uri);
  } on FormatException {
    return null;
  }
}

String? _attribute(String line, String name) {
  return RegExp(
    '(?:^|\\s)$name\\s*=\\s*"([^"]*)"',
    caseSensitive: false,
  ).firstMatch(line)?.group(1);
}

String? _displayName(String line) {
  var insideQuotes = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      insideQuotes = !insideQuotes;
    } else if (character == ',' && !insideQuotes) {
      final name = line.substring(index + 1).trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
}
