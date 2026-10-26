# IPTV Player - Flutter Application

## Descripción
Aplicación IPTV multiplataforma (Android, iOS, Linux, macOS, Web) construida con Flutter que permite reproducir canales de televisión mediante listas de reproducción M3U.

## Características Principales
- **Carga de listas M3U**: Descarga listas remotas, valida la URL y muestra el progreso y los errores
- **Categorías y búsqueda**: Filtra canales por categoría y busca por nombre o URL
- **Favoritos**: Agregar/quitar canales a favoritos
- **Reproducción de streams**: Usa el reproductor mantenido `better_player_plus`
- **Guía de programación (EPG)**: La interfaz indica que no está configurada; hace falta conectar un proveedor EPG real
- **Grabación simulada**: Guarda un archivo de texto; no captura el vídeo del stream
- **Múltiples plataformas**: Disponible en Android, iOS, Linux, macOS y Web

## Estructura del Proyecto
```
iptv_app/
├─ lib/main.dart              # Interfaz y lógica de la aplicación
├─ lib/m3u_parser.dart        # Parser de listas M3U
├─ pubspec.yaml               # Dependencias y configuración
├─ assets/                    # Recursos estáticos (imágenes, M3U, fuentes)
├─ android/                   # Proyecto Android (Kotlin)
├─ ios/                       # Proyecto iOS (Flutter)
├─ linux/                     # Aplicación Linux (Flutter)
├─ macos/                     # Aplicación macOS (Flutter)
├─ web/                       # Aplicación Web (Flutter/PWA)
├─ windows/                   # Aplicación Windows (Flutter)
└─ test/                      # Pruebas unitarias
```

## Dependencias
Las principales dependencias definidas en `pubspec.yaml`:
- `better_player_plus: ^1.4.1` - Reproductor de video compatible con Flutter 3.41+
- `http: ^1.3.0` - Cliente HTTP para descargar listas M3U
- `path_provider: ^2.0.2` - Acceso a directorios del sistema
- `provider: ^6.0.0` - Gestión de estado
- `shared_preferences: ^2.0.5` - Guardar configuraciones locales
- `connectivity_plus: ^6.1.3` - Verificar conexión a internet
- `flutter_local_notifications: ^18.0.1` - Notificaciones locales

## Comportamiento y limitaciones

- El parser respeta `#EXTINF`, `tvg-name`, `group-title` y `#EXTGRP`, ignora directivas de comentario y resuelve direcciones de stream relativas con respecto a la URL de la lista.
- La reproducción marca explícitamente HLS (`.m3u8`), DASH (`.mpd`) y los demás enlaces IPTV como streams directos; Android requiere permiso de Internet también en compilaciones de distribución.
- La descarga tiene un límite de espera de 20 segundos. Los favoritos y la URL no se guardan al cerrar la aplicación.
- La EPG no está conectada a un proveedor. La antigua URL `api.example.com` era solo un marcador de posición y se ha eliminado.
- “Guardar simulación” crea un archivo de texto indicando el stream seleccionado; no graba audio ni vídeo.

## Cómo Ejecutar el Proyecto

### Requisitos Previos
- Flutter SDK instalado
- Dependencias instaladas: `flutter pub get`

### Ejecución
```bash
flutter pub get
flutter run
```

## Notas de Desarrollo
- La aplicación usa `TextEditingController` para el control de entrada de URL
- El reproductor usa `BetterPlayerController` para la gestión de reproducción
- Los archivos de simulación se guardan en el directorio de documentos de la aplicación
- Las pruebas del parser están en `test/m3u_parser_test.dart`

## Advertencias conocidas
- `better_player_plus` requiere Dart 3.11 y Flutter 3.41 como mínimo.