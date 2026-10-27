# IPTV Player - Flutter Application

## Descripción
Aplicación IPTV multiplataforma (Android, iOS, Linux, macOS, Web) construida con Flutter que permite reproducir canales de televisión mediante listas de reproducción M3U.

## Características Principales
- **Carga de listas M3U**: Ingresa una URL de lista M3U para cargar canales de televisión
- **Parseo avanzado de M3U**: Extrae automáticamente títulos, categorías (`group-title`) y logos (`tvg-name`) de los metadatos del archivo
- **Filtro por categorías**: Filtrar canales por las categorías definidas en la lista
- **Búsqueda de canales**: Buscar canales por título o URL en tiempo real
- **Favoritos**: Agregar/quitar canales a favoritos con persistencia en la sesión actual usando `shared_preferences`
- **Reproducción de streams**: Usa `better_player_plus` con detección automática de formato (HLS/MPEG-DASH/other)
- **Manejo de errores**: Mensajes de error significativos (HTTP 403/404, HTTP sin cifrar, errores de decodificador)
- **Guía de programación (EPG)**: Carga desde fuentes XMLTV automáticas (detección de `url-tvg`, `x-tvg-url`, derivación Xtream `xmltv.php`) o configuración manual
- **Controles del reproductor**: Pausa/reproducción, pantalla completa, canal anterior/siguiente, **rewind/avance 10 segundos** y detener
- **Soporte de audio y subtítulos**: Posibilidad de cambiar pistas de audio y subtítulos durante la reproducción mediante API del controlador
- **SIMulación de grabación**: Guardar simulaciones de grabaciones del stream actual como archivos de texto
- **Interfaz de usuario mejorada**: Indicadores de carga, mensajes de error inline, tarjetas con estado de reproducción

## Arquitectura del Proyecto
El proyecto está organizado en dos archivos Dart principales:

### `lib/main.dart`
- Lógica de la página principal, controladores de estado y lógica de negocio
- Manejo de controladores de texto, estado de carga, mensajes de error
- Interfaz de usuario con campos de búsqueda, categorías y lista de canales
- Integración con `better_player_plus` para la reproducción de video
- Persistencia de datos usando `shared_preferences`
- Implementación de seek/rewind dentro de la reproducción

### `lib/m3u_parser.dart`
- **Clase `M3U8Entry`**: Modelo de datos para entradas de playlist con operadores `==` y `hashCode` correctamente implementados (comparación por contenido, no por identidad)
- **Función `parseM3U()`**: Parsea contenido de playlist M3U extrayendo:
  - Títulos desde `#EXTINF` con atributo `tvg-name`
  - Categorías desde `#EXTINF` con atributo `group-title` o `#EXTGRP:`
  - URLs de streaming desde las líneas siguientes a los metadatos
- **Funciones auxiliares**: `_attribute()` y `_displayName()` para extraer valores de atributos codificados
- **Clase `M3UPlaylist`**: Contenedor que agrupa las channels y el EPG URI
- **`inferXtreamEpgUri()`**: Deriva automáticamente la URL EPG desde listas Xtream Codes usando username/password

## Dependencias
Las principales dependencias definidas en `pubspec.yaml`:
- `better_player_plus: ^1.4.1` - Reproductor de video mejorado
- `shared_preferences: ^2.0.5` - Persistencia de datos locales
- `xml: 7.0.1` - Lectura de datos XMLTV
- `http: ^1.3.0` - Cliente HTTP para fetch de listas M3U
- `path_provider: ^2.0.2` - Acceso a directorios del sistema
- `flutter_lints: ^5.0.0` - Lints de Flutter

## Correcciones y Mejoras Aplicadas

### 1. Clase `M3U8Entry` con igualdad por contenido
**Archivo**: `lib/m3u_parser.dart:1-23`
- Agregados operadores `==` y `hashCode` para que la comparación funcione por contenido (url, título, categoría) en lugar de identidad
- Esto habilita correctamente el método `_toggleFavorite()` - ahora al hacer favorito/quitar favorito el estado se actualiza correctamente

### 2. Parser M3U completo
**Archivo**: `lib/m3u_parser.dart:25-68`
- Nueva función `parseM3U()` que parsea listas M3U reales en lugar de usar entradas hardcodeadas
- Extrae `tvg-name` como título, `group-title` como categoría
- Maneja `#EXTGRP:` para categorías de grupos
- Resuelve URLs relativas usando la URL base
- Ignora URLs malformados gracefully

### 3. Persistencia de lista M3U con `shared_preferences`
**Archivo**: `lib/main.dart:97-165`
- Almacenamiento automático de la lista cargada en el almacenamiento local del dispositivo
- En el próximo inicio de la aplicación, la lista se carga automáticamente sin necesidad de ingresar la URL nuevamente
- Datos guardados: canales (título, URL, categoría, tvg-id) y URI EPG
- Métodos añadidos: `_initPreferences()`, `_savePlaylist()`, `_loadSavedPlaylist()`, `_playlistToJson()`, `_playlistFromJson()`

### 4. Mejoras en `_loadM3U`
**Archivo**: `lib/main.dart:47-106`
- Valida que la URL sea correcta (tiene autoridad y esquema http/https)
- Agregado timeout de 20 segundos para la petición HTTP
- Manejo de excepciones con try/catch/finally
- Estado de loading show durante la descarga
- Mensajes de error significativos si la carga falla
- Actualiza `_categories` automáticamente desde la lista parseada
- Mantiene `_selectedCategory` consistente si la nueva lista tiene categorías diferentes

### 5. Mejoras en `_playStream`
**Archivo**: `lib/main.dart:108-139`
- Detecta automáticamente el formato de video:
  - `.m3u8` → HLS
  - `.mpd` → MPEG-DASH
  - Otro → formato general
- Usa `better_player_plus` en lugar de `better_player`
- Configuración de `autoPlay: true`
- Builder de errores personalizado con mensajes significativos
- Habilitado `enableAudioTrackSelection` y `enableSubtitleTrackSelection` en `controlsConfiguration` (disponible mediante API del controlador después de iniciar la reproducción)

### 6. Nuevo widget `PlayerErrorView`
**Archivo**: `lib/main.dart:359-417`
- Widget independiente para mostrar errores de reproducción
- Muestra icono de error, título y mensaje descriptivo
- Botón "Reintentar" para reintentar la reproducción
- Se adapta al height del AspectRatio padre

### 7. Funcionalidad de búsqueda
**Archivo**: `lib/main.dart:255-264, 207-211`
- Campo de texto de búsqueda en la barra superior
- Filtra canales por título o URL en tiempo real
- `_searchQuery` estado que dispara `setState` en cada cambio

### 8. Botones de rewind/avance 10 segundos
**Archivo**: `lib/main.dart:~1030-1045`
- Botón ⏪ "Rebobinar 10s": Retrocede 10 segundos dentro del video actual
- Botón ⏩ "Avanzar 10s": Avanza 10 segundos dentro del video actual
- Implementado mediante `_seekRelative(int seconds)` y `_calculateSeekPosition()`
- Utiliza `controller.seekTo()` para mover la posición de reproducción

### 9. Manejo de controladores y ciclo de vida
**Archivo**: `lib/main.dart:192-198`
- `dispose()` limpia tanto `_urlController` como `_searchController`
- Además de `_controller` del reproductor

### 10. Soporte de EPG desde Xtream Codes
**Archivo**: `lib/m3u_parser.dart:34-68`
- `inferXtreamEpgUri()` transforma automáticamente la URL `get.php` a `xmltv.php`
- Mantiene los parámetros `username` y `password` para acceso a la guía
- Soporta servidores como `572369.solanaflix.com`
- Si la detección automática no funciona, se puede introducir la URL XMLTV desde la pantalla de la guía

## Cómo Ejecutar el Proyecto

### Requisitos Previos
- Flutter SDK instalado (versión compatible con Dart 3.x)
- Dependencias instaladas: `flutter pub get`

### Ejecución
```bash
flutter pub get
flutter run
```

### Notas de Desarrollo
- **Persistencia**: La primera vez que cargues una lista, se guardará automáticamente. Al reiniciar la app, se cargará la lista guardada.
- **Búsqueda**: Funciona en tiempo real mientras el usuario escribe
- **Favoritos**: Se mantienen mientras la aplicación esté en memoria (usando `shared_preferences` en sesiones actuales)
- **Formato de lista**: Las listas M3U deben tener metadatos `#EXTINF` para obtener mejores resultados (títulos y categorías)
- **Audio/subtítulos**: Durante la reproducción, están disponibles mediante la API del controlador `better_player_plus` (métodos `getAudioTracks()`, `getSubtitleTracks()`, `setCurrentAudioTrack()`, `setCurrentSubtitleTrack()`)
- **EPG**: La app detecta automáticamente la URL de la guía desde la cabecera M3U o desde enlaces Xtream Codes con credenciales. Si no encuentra la guía, se puede configurar manualmente desde la pantalla de la guía.
- **Errores de red**: HTTP 403/404, HTTP sin cifrar y errores de decodificador tienen mensajes de ayuda específicos
- **Seek/rewind**: Los botones de 10 segundos funcionan con la mayoría de los streams HLS/VOD, moviendo la posición en milisegundos desde el inicio

## Pantalla de Guía EPG

La app incluye una pantalla de guía de programación accesible desde el botón "Guía TV" en la interfaz principal. Desde allí:
- Se muestra la guía XMLTV descargada
- Se puede configurar una fuente EPG manual si la detección automática falla
- Se muestra el estado de carga y mensajes de error si la guía no se puede interpretar

## Guía EPG y controles

La app descarga la guía XMLTV indicada en la cabecera `#EXTM3U` (`url-tvg`, `x-tvg-url`, `tvg-url` o `epg-url`). Si no existe ese atributo, intenta derivar `xmltv.php` para enlaces Xtream que incluyan `username` y `password`, incluido el servidor `572369.solanaflix.com`. También se puede introducir o cambiar manualmente la URL desde la pantalla de la guía. Se admiten respuestas XMLTV sin comprimir y gzip; los identificadores `tvg-id` de `#EXTINF` deben coincidir con el atributo `channel` del XMLTV.

El reproductor incluye botones para:
- **Canal anterior/siguiente**: Cambiar dentro de la lista actual
- **Pausar/reanudar**: Control de reproducción
- **Pantalla completa**: Modo de pantalla completa
- **Detener**: Detener la reproducción actual
- **⏪ Rebobinar 10s**: Retroceder 10 segundos en el video actual
- **⏩ Avanzar 10s**: Avanzar 10 segundos en el video actual

## Advertencias Conocidas
- `dart analyze` → **No issues found** ✓
- La persistencia usa `shared_preferences` (datos en memoria, no sobreviven desinstalación sin backup)
- Sin soporte offline - se requiere conexión a internet para cargar listas y EPG
- La EPG necesita canales con `tvg-id` coincidente con el atributo `channel` del XMLTV; si la detección automática no funciona, se puede introducir la URL XMLTV desde la pantalla de la guía
- Las pistas de audio y subtítulos están disponibles mediante la API del controlador; la UI para seleccionarlas puede agregarse en futuras actualizaciones