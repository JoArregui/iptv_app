import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: IPTVHomePage(),
    );
  }
}

class IPTVHomePage extends StatefulWidget {
  @override
  _IPTVHomePageState createState() => _IPTVHomePageState();
}

class _IPTVHomePageState extends State<IPTVHomePage> {
  final TextEditingController _urlController = TextEditingController();
  BetterPlayerController? _controller;
  List<M3U8Entry> _channels = [];
  List<M3U8Entry> _favorites = [];
  String _selectedCategory = 'Todas';
  Set<String> _categories = {'Todas'};
  String? _currentPlaying;
  String _programGuide = "Cargando guía de programación...";

  // Simulación de cargar una lista de canales M3U (esto debería ser reemplazado por tu lógica)
  void _loadM3U() async {
    if (_urlController.text.isNotEmpty) {
      // Aquí sería donde parsearías un archivo M3U o similar
      // Simulamos una lista de canales
      List<M3U8Entry> entries = [
        M3U8Entry(title: "Canal 1", url: "http://url_del_canal_1"),
        M3U8Entry(title: "Canal 2", url: "http://url_del_canal_2"),
      ];
      setState(() {
        _channels = entries;
        _categories.addAll(entries
            .map((e) => 'Sin categoría')); // Suponiendo que no hay categorías
      });
    }
  }

  void _playStream(String url) {
    _controller?.dispose();
    BetterPlayerDataSource dataSource = BetterPlayerDataSource.network(url);
    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
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
      _fetchProgramGuide(url);
    });
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

  Future<void> _fetchProgramGuide(String url) async {
    // Simulación de carga de guía de programación desde una API externa
    final String epgApiUrl = "https://api.example.com/epg?channel=$url";
    try {
      final response = await http.get(Uri.parse(epgApiUrl));
      if (response.statusCode == 200) {
        final epgData = json.decode(response.body);
        setState(() {
          _programGuide = epgData['current_program'] ?? "No disponible";
        });
      } else {
        setState(() {
          _programGuide = "No se pudo cargar la guía de programación";
        });
      }
    } catch (e) {
      setState(() {
        _programGuide = "Error al obtener la guía de programación";
      });
    }
  }

  Future<void> _recordStream() async {
    if (_currentPlaying == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/grabacion_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(filePath)
        .writeAsString("Simulación de grabación de $_currentPlaying");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Grabación guardada en: $filePath')),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<M3U8Entry> filteredChannels = _selectedCategory == 'Favoritos'
        ? _favorites
        : _selectedCategory == 'Todas'
            ? _channels
            : _channels.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: Text('IPTV Player')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration:
                  InputDecoration(labelText: 'Ingrese URL de lista M3U'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loadM3U,
              child: Text('Cargar Lista'),
            ),
            SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedCategory,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList()
                ..add(DropdownMenuItem(
                    value: 'Favoritos', child: Text('Favoritos'))),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filteredChannels.length,
                itemBuilder: (context, index) {
                  final channel = filteredChannels[index];
                  return ListTile(
                    title: Text(channel.title ?? 'Canal ${index + 1}'),
                    subtitle: Text(channel.url),
                    trailing: IconButton(
                      icon: Icon(
                        _favorites.contains(channel)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _favorites.contains(channel) ? Colors.red : null,
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
                    child: Text('Grabar'),
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

// Simulación de la clase M3U8Entry (esto debería ser reemplazado con el modelo real)
class M3U8Entry {
  final String? title;
  final String url;
  final String? category;

  M3U8Entry({this.title, required this.url, this.category});
}
