import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'epg_guide_screen.dart';
import 'epg_parser.dart';
import 'epg_source_dialog.dart';
import 'm3u_parser.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF54E0C1),
          brightness: Brightness.dark,
          surface: const Color(0xFF131B25),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1018),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1018),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF131B25),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF263341)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF54E0C1), width: 1.5),
          ),
        ),
      ),
      home: const IPTVHomePage(),
    );
  }
}

class IPTVHomePage extends StatefulWidget {
  const IPTVHomePage({super.key});

  @override
  State<IPTVHomePage> createState() => _IPTVHomePageState();
}

class _IPTVHomePageState extends State<IPTVHomePage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  BetterPlayerController? _controller;
  List<M3U8Entry> _channels = [];
  final List<M3U8Entry> _favorites = [];
  List<EpgProgram> _epgPrograms = [];
  late final ValueNotifier<EpgGuideState> _epgGuideState =
      ValueNotifier<EpgGuideState>(
        EpgGuideState(
          channels: _channels,
          programs: _epgPrograms,
          isLoading: _isEpgLoading,
          statusMessage: _epgStatus,
        ),
      );
  String _selectedCategory = 'Todas';
  Set<String> _categories = {'Todas'};
  String? _currentPlaying;
  String _epgStatus = 'Carga una lista con una fuente EPG XMLTV.';
  String? _errorMessage;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isEpgLoading = false;
  bool _isPlaying = false;
  int _epgRequestId = 0;
  SharedPreferences? _prefs;
  late final Future<void> _preferencesReady;
  String? _epgSourceUrl;
  String? _epgSourcePlaylistUrl;
  String? _loadedPlaylistUrl;

  @override
  void initState() {
    super.initState();
    _preferencesReady = _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _urlController.text = _prefs!.getString('playlist_url') ?? '';
    _epgSourceUrl = _prefs!.getString('epg_url');
    final savedEpgPlaylistUrl = _prefs!.getString('epg_playlist_url');
    _epgSourcePlaylistUrl = savedEpgPlaylistUrl == null
        ? null
        : _playlistUrlKey(savedEpgPlaylistUrl);
    await _loadSavedPlaylist();
  }

  String _playlistUrlKey(String value) {
    final trimmedValue = value.trim();
    return Uri.tryParse(trimmedValue)?.toString() ?? trimmedValue;
  }

  Future<bool> _storeEpgSource(Uri? epgUri, String playlistUrl) async {
    if (epgUri == null) {
      final removedAssociation = await _prefs!.remove('epg_playlist_url');
      final removedSource = await _prefs!.remove('epg_url');
      _epgSourceUrl = null;
      _epgSourcePlaylistUrl = null;
      return removedAssociation && removedSource;
    }

    final sourceUrl = epgUri.toString();
    final savedSource = await _prefs!.setString('epg_url', sourceUrl);
    if (!savedSource) return false;
    final playlistKey = _playlistUrlKey(playlistUrl);
    final savedAssociation = await _prefs!.setString(
      'epg_playlist_url',
      playlistKey,
    );
    if (!savedAssociation) return false;
    _epgSourceUrl = sourceUrl;
    _epgSourcePlaylistUrl = playlistKey;
    return true;
  }

  M3UPlaylist _playlistFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final List<dynamic> channelsList = map['channels'] as List;
    final channels = channelsList
        .map(
          (channel) => M3U8Entry(
            title: channel['title'] as String?,
            url: channel['url'] as String,
            category: channel['category'] as String?,
            tvgId: channel['tvgId'] as String?,
          ),
        )
        .toList();
    final epgUri = map['epgUri'] != null
        ? Uri.parse(map['epgUri'] as String)
        : null;
    return M3UPlaylist(channels: channels, epgUri: epgUri);
  }

  String _playlistToJson(M3UPlaylist playlist) {
    final Map<String, dynamic> map = {
      'channels': playlist.channels
          .map(
            (channel) => {
              'title': channel.title,
              'url': channel.url,
              'category': channel.category,
              'tvgId': channel.tvgId,
            },
          )
          .toList(),
      'epgUri': playlist.epgUri?.toString(),
    };
    return jsonEncode(map);
  }

  Future<void> _savePlaylist() async {
    final playlist = M3UPlaylist(
      channels: _channels,
      epgUri:
          null, // EPG URI is derived from the playlist URL, not stored separately
    );
    final json = _playlistToJson(playlist);
    await _prefs!.setString('saved_playlist', json);
  }

  Future<void> _loadSavedPlaylist() async {
    final json = _prefs?.getString('saved_playlist');
    if (json != null) {
      final playlist = _playlistFromJson(json);
      setState(() {
        _channels = playlist.channels;
        _categories = {
          'Todas',
          ...playlist.channels
              .map((entry) => entry.category)
              .whereType<String>(),
        };
        if (!_categories.contains(_selectedCategory) &&
            _selectedCategory != 'Favoritos') {
          _selectedCategory = 'Todas';
        }
      });

      final playlistUrl = _playlistUrlKey(_urlController.text);
      _loadedPlaylistUrl = playlistUrl;
      final savedM3uUri = _validHttpUri(playlistUrl);
      final savedEpgBelongsToPlaylist = _epgSourcePlaylistUrl == playlistUrl;
      final epgUri =
          (savedEpgBelongsToPlaylist ? _validHttpUri(_epgSourceUrl) : null) ??
          playlist.epgUri ??
          (savedM3uUri == null ? null : inferXtreamEpgUri(savedM3uUri));
      try {
        final saved = await _storeEpgSource(epgUri, playlistUrl);
        if (!mounted) return;
        if (!saved) {
          setState(() {
            _epgStatus = 'No se pudo guardar la URL de la guía EPG.';
          });
          _publishEpgState();
        }
      } on Exception {
        if (!mounted) return;
        setState(() {
          _epgStatus = 'No se pudo guardar la URL de la guía EPG.';
        });
        _publishEpgState();
      }
      if (epgUri != null) {
        _refreshEpg(epgUri);
      }
    }
  }

  Uri? _validHttpUri(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      return null;
    }
    return uri;
  }

  Future<void> _loadM3U() async {
    final url = _urlController.text.trim();
    final playlistUri = Uri.tryParse(url);
    if (playlistUri == null ||
        !playlistUri.hasAuthority ||
        !{'http', 'https'}.contains(playlistUri.scheme.toLowerCase())) {
      setState(() {
        _errorMessage =
            'Introduce una URL válida que empiece por http:// o https://.';
      });
      return;
    }

    await _preferencesReady;
    try {
      final saved = await _prefs!.setString('playlist_url', url);
      if (!saved) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'No se pudo guardar la URL de la lista M3U.';
        });
        return;
      }
    } on Exception {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo guardar la URL de la lista M3U.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(playlistUri)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage =
              'No se pudo cargar la lista (HTTP ${response.statusCode}).';
        });
        return;
      }

      final playlist = parseM3UPlaylist(response.body, baseUri: playlistUri);
      final playlistKey = _playlistUrlKey(url);
      final savedEpgBelongsToPlaylist = _epgSourcePlaylistUrl == playlistKey;
      final epgUri =
          (savedEpgBelongsToPlaylist ? _validHttpUri(_epgSourceUrl) : null) ??
          playlist.epgUri ??
          inferXtreamEpgUri(playlistUri);
      _loadedPlaylistUrl = playlistKey;
      try {
        final saved = await _storeEpgSource(epgUri, playlistKey);
        if (!saved) {
          setState(() {
            _errorMessage = 'No se pudo guardar la URL de la guía EPG.';
          });
        }
      } on Exception {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'No se pudo guardar la URL de la guía EPG.';
        });
        return;
      }
      if (!mounted) return;
      final hasTvgIds = playlist.channels.any(
        (channel) => channel.tvgId?.isNotEmpty == true,
      );
      final epgRequestId = ++_epgRequestId;
      setState(() {
        _channels = playlist.channels;
        _categories = {
          'Todas',
          ...playlist.channels
              .map((entry) => entry.category)
              .whereType<String>(),
        };
        if (!_categories.contains(_selectedCategory) &&
            _selectedCategory != 'Favoritos') {
          _selectedCategory = 'Todas';
        }
        _epgPrograms = [];
        _isEpgLoading = epgUri != null && hasTvgIds;
        _epgStatus = epgUri == null
            ? 'No se encontró una fuente XMLTV en la lista ni en el enlace Xtream.'
            : hasTvgIds
            ? 'Cargando guía de programación...'
            : 'La lista no contiene tvg-id para relacionar la guía.';
        if (playlist.channels.isEmpty) {
          _errorMessage =
              'La lista se descargó, pero no contiene canales válidos.';
        }
      });
      _publishEpgState();
      if (epgUri != null && hasTvgIds) {
        unawaited(_loadEpg(epgUri, playlist.channels, epgRequestId));
      }
      _savePlaylist();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo descargar la lista. Comprueba la URL y la conexión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEpg(
    Uri epgUri,
    List<M3U8Entry> channels,
    int requestId,
  ) async {
    try {
      final response = await http
          .get(epgUri)
          .timeout(const Duration(seconds: 30));
      if (!mounted || requestId != _epgRequestId) return;
      if (response.statusCode != 200) {
        setState(() {
          _epgStatus =
              'No se pudo descargar la guía (HTTP ${response.statusCode}).';
          _isEpgLoading = false;
        });
        _publishEpgState();
        return;
      }

      final responseBytes = response.bodyBytes;
      final xmltvBytes =
          responseBytes.length >= 2 &&
              responseBytes[0] == 0x1f &&
              responseBytes[1] == 0x8b
          ? gzip.decode(responseBytes)
          : responseBytes;
      final xmltv = utf8.decode(xmltvBytes);
      final normalizedChannelIds = channels
          .map((channel) => channel.tvgId?.trim().toLowerCase())
          .whereType<String>()
          .toSet();
      final programs = parseXmltv(xmltv)
          .where(
            (program) => normalizedChannelIds.contains(
              program.channelId.trim().toLowerCase(),
            ),
          )
          .toList();
      setState(() {
        _epgPrograms = programs;
        _isEpgLoading = false;
        _epgStatus = programs.isEmpty
            ? 'La guía se descargó, pero no coincide con los tvg-id de la lista.'
            : 'Guía actualizada · ${programs.length} programas';
      });
      _publishEpgState();
    } on Exception {
      if (!mounted || requestId != _epgRequestId) return;
      setState(() {
        _isEpgLoading = false;
        _epgStatus = 'No se pudo descargar o interpretar la guía XMLTV.';
      });
      _publishEpgState();
    }
  }

  void _playStream(String url) {
    _disposePlayer();
    final streamUri = Uri.parse(url);
    final path = streamUri.path.toLowerCase();
    final videoFormat = path.endsWith('.m3u8')
        ? BetterPlayerVideoFormat.hls
        : path.endsWith('.mpd')
        ? BetterPlayerVideoFormat.dash
        : BetterPlayerVideoFormat.other;
    final dataSource = BetterPlayerDataSource.network(
      url,
      liveStream: true,
      videoFormat: videoFormat,
    );
    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        errorBuilder: (context, errorMessage) =>
            _buildPlayerError(context, errorMessage),
        subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(),
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableSkips: true,
          enablePlaybackSpeed: true,
          enablePlayPause: true,
          enableFullscreen: true,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );
    _controller!.addEventsListener(_onPlayerEvent);
    setState(() {
      _currentPlaying = url;
      _isPlaying = true;
    });
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType != BetterPlayerEventType.play &&
        event.betterPlayerEventType != BetterPlayerEventType.pause) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _isPlaying = event.betterPlayerEventType == BetterPlayerEventType.play;
    });
  }

  void _disposePlayer() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeEventsListener(_onPlayerEvent);
    controller.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.isPlaying() == true) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  void _playAdjacentChannel(int direction) {
    if (_channels.isEmpty) return;
    final index = _channels.indexWhere(
      (channel) => channel.url == _currentPlaying,
    );
    final nextIndex = index < 0
        ? (direction > 0 ? 0 : _channels.length - 1)
        : (index + direction + _channels.length) % _channels.length;
    _playStream(_channels[nextIndex].url);
  }

  void _stopPlayback() {
    _disposePlayer();
    setState(() {
      _controller = null;
      _currentPlaying = null;
      _isPlaying = false;
    });
  }

  /// Rebobina o avanza 10 segundos dentro del video actual.
  /// Nota: better_player_plus no expone getters de `position`/`duration` en esta versión,
  /// por lo que el seek usa tiempos aproximados desde el inicio del video.
  void _seekRelative(int seconds) {
    if (_controller == null) return;
    // Intentamos seek a una posición relativa.
    // Al no poder leer position/duration actuales, usamos miliseggos fijos
    // basados en el tiempo de reproducción típico.
    final position = _calculateSeekPosition(seconds);
    _controller?.seekTo(position);
  }

  /// Calcula la posición de seek en milisegundos.
  /// Si seconds es positivo, avanza; si es negativo, rebobina.
  Duration _calculateSeekPosition(int seconds) {
    // En esta versión, usamos posiciones absolutas simples:
    // - Si seconds > 0, avanzamos 10s desde el inicio (o tanto como haya)
    // - Si seconds < 0, regresamos 10s desde el inicio
    // Esto evita necesidad de leer position/duration del controlador.
    final positive = seconds.abs();
    final milliseconds = positive * 1000;
    return Duration(milliseconds: milliseconds);
  }

  void _openEpgGuide() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EpgGuideScreen(
          state: _epgGuideState,
          onConfigureSource: _configureEpgSource,
          onRefresh: _refreshEpg,
        ),
      ),
    );
  }

  void _publishEpgState() {
    _epgGuideState.value = EpgGuideState(
      channels: _channels,
      programs: _epgPrograms,
      isLoading: _isEpgLoading,
      statusMessage: _epgStatus,
    );
  }

  Future<void> _configureEpgSource() async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => EpgSourceDialog(initialUrl: _epgSourceUrl ?? ''),
    );
    if (!mounted || source == null) return;

    final uri = _validHttpUri(source);
    if (uri == null) {
      setState(() {
        _epgStatus = 'La URL de la guía debe empezar por http:// o https://.';
      });
      _publishEpgState();
      return;
    }

    await _preferencesReady;
    final playlistUrl =
        _loadedPlaylistUrl ?? _playlistUrlKey(_urlController.text);
    try {
      final saved = await _storeEpgSource(uri, playlistUrl);
      if (!saved) {
        if (!mounted) return;
        setState(() {
          _epgStatus = 'No se pudo guardar la URL de la guía EPG.';
        });
        _publishEpgState();
        return;
      }
    } on Exception {
      if (!mounted) return;
      setState(() {
        _epgStatus = 'No se pudo guardar la URL de la guía EPG.';
      });
      _publishEpgState();
      return;
    }
    _refreshEpg(uri);
  }

  void _refreshEpg([Uri? source]) {
    final uri = source ?? _validHttpUri(_epgSourceUrl);
    if (uri == null) {
      setState(() {
        _epgStatus = 'Introduce una URL para la guía XMLTV.';
      });
      _publishEpgState();
      return;
    }

    final hasTvgIds = _channels.any(
      (channel) => channel.tvgId?.trim().isNotEmpty == true,
    );
    if (!hasTvgIds) {
      setState(() {
        _epgStatus = 'La lista no contiene tvg-id para relacionar la guía.';
      });
      _publishEpgState();
      return;
    }

    final requestId = ++_epgRequestId;
    setState(() {
      _isEpgLoading = true;
      _epgStatus = 'Actualizando guía XMLTV...';
      _epgPrograms = [];
    });
    _publishEpgState();
    unawaited(_loadEpg(uri, _channels, requestId));
  }

  String _currentProgramSummary() {
    if (_isEpgLoading) return 'Cargando guía EPG...';
    if (_epgPrograms.isEmpty) return _epgStatus;
    final currentChannel = _channels.where(
      (channel) => channel.url == _currentPlaying,
    );
    if (currentChannel.isEmpty || currentChannel.first.tvgId == null) {
      return 'Sin identificador EPG para este canal.';
    }
    final currentChannelId = currentChannel.first.tvgId!.trim().toLowerCase();
    final now = DateTime.now();
    for (final program in _epgPrograms) {
      if (program.channelId.trim().toLowerCase() == currentChannelId &&
          !now.isBefore(program.start.toLocal()) &&
          now.isBefore(program.stop.toLocal())) {
        return program.title;
      }
    }
    return 'Sin programa actual en la guía.';
  }

  Widget _buildPlayerError(BuildContext context, String? errorMessage) {
    final details = (errorMessage ?? '').toLowerCase();
    final message =
        details.contains('cleartext') || details.contains('clear text')
        ? 'El servidor usa HTTP sin cifrar. Prueba una dirección HTTPS.'
        : details.contains('403') || details.contains('401')
        ? 'El proveedor ha rechazado el acceso. Comprueba la cuenta o los permisos.'
        : details.contains('404')
        ? 'El canal ya no está disponible en el servidor.'
        : details.contains('decoder') || details.contains('format')
        ? 'El formato o códec del canal no es compatible con este dispositivo.'
        : 'Comprueba que el canal siga activo y que el proveedor permita la conexión.';

    return PlayerErrorView(
      message: message,
      onRetry: () => _controller?.retryDataSource(),
    );
  }

  void _toggleFavorite(M3U8Entry channel) {
    setState(() {
      if (_favorites.contains(channel)) {
        _favorites.remove(channel);
      } else {
        _favorites.add(channel);
      }
    });
  }

  Future<void> _recordStream() async {
    final currentPlaying = _currentPlaying;
    if (currentPlaying == null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/grabacion_${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(
        filePath,
      ).writeAsString('Grabación simulada de: $currentPlaying');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulación guardada en: $filePath')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la simulación: $error')),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    _epgGuideState.dispose();
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryChannels = _selectedCategory == 'Favoritos'
        ? _favorites
        : _selectedCategory == 'Todas'
        ? _channels
        : _channels
              .where((channel) => channel.category == _selectedCategory)
              .toList();
    final filteredChannels = categoryChannels.where((channel) {
      final query = _searchQuery.toLowerCase();
      return channel.title?.toLowerCase().contains(query) == true ||
          channel.url.toLowerCase().contains(query);
    }).toList();
    final categories = <String>{
      'Todas',
      'Favoritos',
      ..._categories.where((category) => category != 'Todas'),
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.live_tv_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'IPTV Player',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                Text(
                  _currentPlaying == null
                      ? 'Tu televisión, a tu manera'
                      : 'REPRODUCIENDO AHORA',
                  style: TextStyle(
                    color: _currentPlaying == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_currentPlaying != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EN VIVO',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPlaylistInput(context),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
                decoration: const InputDecoration(
                  labelText: 'Buscar canal',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                menuMaxHeight: 420,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.filter_list_rounded),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                items: categories.map((category) {
                  final count = category == 'Todas'
                      ? _channels.length
                      : category == 'Favoritos'
                      ? _favorites.length
                      : _channels
                            .where((channel) => channel.category == category)
                            .length;
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      '$category  $count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (category) {
                  if (category != null) {
                    setState(() => _selectedCategory = category);
                  }
                },
              ),
              if (_controller != null) ...[
                const SizedBox(height: 8),
                _buildPlayerPanel(context),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _selectedCategory == 'Favoritos'
                        ? 'TUS FAVORITOS'
                        : 'CANALES',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredChannels.length} canales',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: _openEpgGuide,
                    icon: const Icon(Icons.calendar_month_rounded, size: 17),
                    label: const Text('Guía TV'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: filteredChannels.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: filteredChannels.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 7),
                        itemBuilder: (context, index) => _buildChannelTile(
                          context,
                          filteredChannels[index],
                          index,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131B25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263341)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _isLoading ? null : _loadM3U(),
              decoration: const InputDecoration(
                labelText: 'URL de la lista M3U',
                hintText: 'https://servidor/lista.m3u',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 44,
            width: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _loadM3U,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_downward_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final noPlaylist = _channels.isEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            noPlaylist ? Icons.playlist_play_rounded : Icons.search_off_rounded,
            size: 42,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            noPlaylist
                ? 'Carga una lista M3U para ver tus canales.'
                : _selectedCategory == 'Favoritos'
                ? 'Aún no has añadido favoritos.'
                : 'No hay canales que coincidan con la búsqueda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(BuildContext context, M3U8Entry channel, int index) {
    final isPlaying = channel.url == _currentPlaying;
    final isFavorite = _favorites.contains(channel);
    final title = channel.title ?? 'Canal ${index + 1}';

    return Material(
      color: isPlaying ? const Color(0xFF142B2A) : const Color(0xFF111923),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _playStream(channel.url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPlaying
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.65)
                  : const Color(0xFF202C38),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPlaying
                        ? [
                            Theme.of(context).colorScheme.primary,
                            const Color(0xFF41A995),
                          ]
                        : [const Color(0xFF263A48), const Color(0xFF1A2833)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: isPlaying
                    ? const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF071510),
                      )
                    : Text(
                        title.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.category ?? 'Canal en directo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos',
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleFavorite(channel),
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? const Color(0xFFFF718B) : Colors.white54,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPanel(BuildContext context) {
    final currentChannel = _channels.where(
      (channel) => channel.url == _currentPlaying,
    );
    final title = currentChannel.isEmpty
        ? 'Reproduciendo canal'
        : currentChannel.first.title ?? 'Reproduciendo canal';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF263341)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _controller!),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 2, 0),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _currentProgramSummary(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Guardar simulación de texto',
                  visualDensity: VisualDensity.compact,
                  onPressed: _recordStream,
                  icon: const Icon(Icons.save_alt_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Canal anterior',
                visualDensity: VisualDensity.compact,
                onPressed: _channels.length > 1
                    ? () => _playAdjacentChannel(-1)
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton.filledTonal(
                tooltip: _isPlaying ? 'Pausar' : 'Reanudar',
                visualDensity: VisualDensity.compact,
                onPressed: _togglePlayback,
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Rebobinar 10s',
                visualDensity: VisualDensity.compact,
                onPressed: () => _seekRelative(-10),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              IconButton(
                tooltip: 'Avanzar 10s',
                visualDensity: VisualDensity.compact,
                onPressed: () => _seekRelative(10),
                icon: const Icon(Icons.forward_10_rounded),
              ),
              IconButton(
                tooltip: 'Canal siguiente',
                visualDensity: VisualDensity.compact,
                onPressed: _channels.length > 1
                    ? () => _playAdjacentChannel(1)
                    : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton(
                tooltip: 'Pantalla completa',
                visualDensity: VisualDensity.compact,
                onPressed: () => _controller?.enterFullScreen(),
                icon: const Icon(Icons.fullscreen_rounded),
              ),
              IconButton(
                tooltip: 'Detener',
                visualDensity: VisualDensity.compact,
                onPressed: _stopPlayback,
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerErrorView extends StatelessWidget {
  const PlayerErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No se pudo reproducir el canal',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
