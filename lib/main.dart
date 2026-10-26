import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: IPTVHomePage(),
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
  String _selectedCategory = 'Todas';
  Set<String> _categories = {'Todas'};
  String? _currentPlaying;
  String _programGuide = 'Selecciona un canal para reproducirlo.';
  String? _errorMessage;
  String _searchQuery = '';
  bool _isLoading = false;

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

      final entries = parseM3U(response.body, baseUri: playlistUri);
      setState(() {
        _channels = entries;
        _categories = {
          'Todas',
          ...entries.map((entry) => entry.category).whereType<String>(),
        };
        if (!_categories.contains(_selectedCategory) &&
            _selectedCategory != 'Favoritos') {
          _selectedCategory = 'Todas';
        }
        if (entries.isEmpty) {
          _errorMessage =
              'La lista se descargó, pero no contiene canales válidos.';
        }
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar la lista: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playStream(String url) {
    _controller?.dispose();
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
        ),
      ),
      betterPlayerDataSource: dataSource,
    );
    setState(() {
      _currentPlaying = url;
      _programGuide = 'Guía EPG no configurada.';
    });
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryChannels = _selectedCategory == 'Favoritos'
        ? _favorites
        : _selectedCategory == 'Todas'
        ? _channels
        : _channels.where((c) => c.category == _selectedCategory).toList();
    final filteredChannels = categoryChannels.where((channel) {
      final query = _searchQuery.toLowerCase();
      return channel.title?.toLowerCase().contains(query) == true ||
          channel.url.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('IPTV Player')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _isLoading ? null : _loadM3U(),
              decoration: const InputDecoration(
                labelText: 'URL de la lista M3U',
                hintText: 'https://servidor/lista.m3u',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadM3U,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add),
                label: Text(_isLoading ? 'Cargando...' : 'Cargar lista'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              decoration: const InputDecoration(
                labelText: 'Buscar canal',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedCategory,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedCategory = value;
                });
              },
              items:
                  _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList()..add(
                    DropdownMenuItem(
                      value: 'Favoritos',
                      child: Text('Favoritos'),
                    ),
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredChannels.isEmpty
                  ? Center(
                      child: Text(
                        _channels.isEmpty
                            ? 'Carga una lista M3U para ver tus canales.'
                            : 'No hay canales que coincidan con la búsqueda.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredChannels.length,
                      itemBuilder: (context, index) {
                        final channel = filteredChannels[index];
                        final isPlaying = channel.url == _currentPlaying;
                        final isFavorite = _favorites.contains(channel);
                        return ListTile(
                          leading: Icon(
                            isPlaying ? Icons.equalizer : Icons.tv,
                            color: isPlaying
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(channel.title ?? 'Canal ${index + 1}'),
                          subtitle: Text(
                            channel.category ?? channel.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: isFavorite
                                ? 'Quitar de favoritos'
                                : 'Añadir a favoritos',
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : null,
                            ),
                            onPressed: () => _toggleFavorite(channel),
                          ),
                          onTap: () => _playStream(channel.url),
                        );
                      },
                    ),
            ),
            if (_controller != null) ...[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: BetterPlayer(controller: _controller!),
              ),
              SizedBox(height: 10),
              Text(_programGuide),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _recordStream,
                    child: const Text('Guardar simulación'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
