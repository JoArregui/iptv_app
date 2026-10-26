# IPTV Player - Flutter Application

## Descripción
Aplicación IPTV multiplataforma (Android, iOS, Linux, macOS, Web) construida con Flutter que permite reproducir canales de televisión mediante listas de reproducción M3U.

## Características Principales
- **Carga de listas M3U**: Ingresa una URL de lista M3U para cargar canales de televisión
- **Parseo avanzado de M3U**: Extrae automáticamente títulos, categorías (`group-title`) y logos (`tvg-name`) de los metadatos del archivo
- **Filtro por categorías**: Filtrar canales por las categorías definidas en la lista
- **Búsqueda de canales**: Buscar canales por título o URL en tiempo real
- **Favoritos**: Agregar/quitar canales a favoritos con persistencia en la sesión actual
- **Reproducción de streams**: Usa `better_player_plus` con detección automática de formato (HLS/MPEG-DASH/other)
- **Manejo de errores**: Mensajes de error significativos (HTTP 403/404, HTTP sin cifrar, errores de decodificador)
- **Guía de programación (EPG)**: Parrilla de las próximas 24 horas desde la fuente XMLTV de la lista o una URL configurada manualmente
- **Controles del reproductor**: Pausa/reproducción, pantalla completa, canal anterior/siguiente y detener
- **Grabación simulada**: Guardar simulaciones de grabaciones del stream actual como archivos de texto
- **Interfaz de usuario mejorada**: Indicadores de carga, mensajes de error inline, tarjetas con estado de reproducción

## Arquitectura del Proyecto
El proyecto ahora está organizado en dos archivos Dart principales:

### `lib/main.dart`
- Lógica de la página principal, controladores de estado y lógica de negocio
- Manejo de controladores de texto, estado de carga, mensajes de error
- Interfaz de usuario con campos de búsqueda, categorías y lista de canales
- Integración con `better_player_plus` para la reproducción de video

### `lib/m3u_parser.dart`
- **Clase `M3U8Entry`**: Modelo de datos para entradas de playlist con operadores `==` y `hashCode` correctamente implementados (comparación por contenido, no por identidad)
- **Función `parseM3U()`**: Parsea contenido de playlist M3U extrayendo:
  - Títulos desde `#EXTINF` con atributo `tvg-name`
  - Categorías desde `#EXTINF` con atributo `group-title` o `#EXTGRP:`
  - URLs de streaming desde las líneas siguientes a los metadatos
- **Funciones auxiliares**: `_attribute()` y `_displayName()` para extraer valores de atributos codificados

## Dependencias
Las principales dependencias definidas en `pubspec.yaml`:
- `better_player_plus: ^1.4.1` - Reproductor de video mejorado
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
- Ignora URLs malformados graceful

### 3. Mejoras en `_loadM3U`
**Archivo**: `lib/main.dart:47-106`
- Valida que la URL sea correcta (tiene autoridad y esquema http/https)
- Agregado timeout de 20 segundos para la petición HTTP
- Manejo de excepciones con try/catch/finally
- Estado de loading show durante la descarga
- Mensajes de error significativos si la carga falla
- Actualiza `_categories` automáticamente desde la lista parseada
- Mantiene `_selectedCategory` consistente si la nueva lista tiene categorías diferentes

### 4. Mejoras en `_playStream`
**Archivo**: `lib/main.dart:108-139`
- Detecta automáticamente el formato de video:
  - `.m3u8` → HLS
  - `.mpd` → MPEG-DASH
  - Otro → formato general
- Usa `better_player_plus` en lugar de `better_player`
- Configuración de `autoPlay: true`
- Builder de errores personalizado con mensajes significativos

### 5. Nuevo widget `PlayerErrorView`
**Archivo**: `lib/main.dart:359-417`
- Widget independiente para mostrar errores de reproducción
- Muestra icono de error, título y mensaje descriptivo
- Botón "Reintentar" para reintentar la reproducción
- Se adapta al height del AspectRatio padre

### 6. Funcionalidad de búsqueda
**Archivo**: `lib/main.dart:255-264, 207-211`
- Campo de texto de búsqueda en la barra superior
- Filtra canales por título o URL en tiempo real
- `_searchQuery` estado que dispara `setState` en cada cambio

### 7. Mejoras en la interfaz de usuario
**Archivo**: `lib/main.dart:213-356`
- Indicador de carga mostrado durante la descarga de la lista
- Mensajes de error mostrados inline debajo del campo de URL
- Tarjetas de canal con indicador "Igualando" cuando está reproduciéndose
- Iconos de favorito con tooltip y color rojo cuando están marcados
- Diseño más limpio con `InputDecoration` con borde outline
- Botón `ElevatedButton.icon` con icono de lista de reproducción

### 8. Manejo de controladores y ciclo de vida
**Archivo**: `lib/main.dart:192-198`
- `dispose()` limpia tanto `_urlController` como `_searchController`
- Además de `_controller` del reproductor

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
- Las listas M3U deben tener formato estándar con metadatos `#EXTINF` para obtener mejores resultados (títulos y categorías)
- La búsqueda funciona en tiempo real mientras el usuario escribe
- Las favoritos se mantienen mientras la aplicación esté en memoria (no persisten entre reinicios)
- El reproductor detecta automáticamente el formato basándose en la extensión de la URL
- Los errores de red (403, 404, HTTP sin cifrar) tienen mensajes de ayuda específicos

## Advertencias Conocidas
- Ningún issue encontrado tras `dart analyze`
- Las favoritos se pierden al cerrar la aplicación (no persisten en SharedPreferences aún)
- Sin soporte offline - se requiere conexión a internet para cargar listas y EPG
- La EPG necesita canales con `tvg-id` coincidente con el atributo `channel` del XMLTV; si la detección automática no funciona, se puede introducir la URL XMLTV desde la pantalla de la guía

## Guía EPG y controles

La app descarga la guía XMLTV indicada en la cabecera `#EXTM3U` (`url-tvg`, `x-tvg-url`, `tvg-url` o `epg-url`). Si no existe ese atributo, intenta derivar `xmltv.php` para enlaces Xtream que incluyan `username` y `password`, incluido el servidor `572369.solanaflix.com`. También se puede introducir o cambiar manualmente la URL desde la pantalla de guía. Se admiten respuestas XMLTV sin comprimir y gzip; los identificadores `tvg-id` de `#EXTINF` deben coincidir con el atributo `channel` del XMLTV.

El reproductor incluye botones para canal anterior/siguiente (en el orden de la lista), pausar/reanudar, pantalla completa y detener.