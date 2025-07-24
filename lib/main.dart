import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

// Inicializa la aplicación y ejecuta el widget principal
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
// Widget principal de la aplicación, configura el tema oscuro y la pantalla inicial
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MusicPlayerScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

// Pantalla principal del reproductor de música
class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

// Estado y lógica del reproductor de música
class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  
  List<File> _songs = [];
  List<File> _filteredSongs = [];
  bool _loading = false;
  int? _currentIndex;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isScanning = false;
    bool _isRandomMode = false;
  Set<String> _favorites = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _createAudioPlayer();
    _requestAudioPermission();
  }

  // Crea y configura el reproductor de audio
  void _createAudioPlayer() {
    _audioPlayer = AudioPlayer()
      ..setReleaseMode(ReleaseMode.loop)
      ..setVolume(0.8);
    _audioPlayer!.setAudioContext(const AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.music,
        audioFocus: AndroidAudioFocus.gain,
        stayAwake: false,
        isSpeakerphoneOn: false,
      ),
    ));
    _setupAudioListeners();
  }

  // Cancela las suscripciones a los eventos del reproductor
  void _cancelAudioListeners() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _playerStateSub = null;
    _durationSub = null;
    _positionSub = null;
    _completeSub = null;
  }

  // Carga las preferencias guardadas del usuario
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isRandomMode = prefs.getBool('isRandomMode') ?? false;
      _favorites = Set.from(prefs.getStringList('favorites') ?? []);
    });
  }

  // Guarda las preferencias del usuario
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRandomMode', _isRandomMode);
    await prefs.setStringList('favorites', _favorites.toList());
  }

  // Guarda la última canción reproducida y su posición
  Future<void> _saveLastPlayed() async {
    if (_currentIndex != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastIndex', _currentIndex!);
      await prefs.setInt('lastPosition', _position.inSeconds);
    }
  }

  // Carga la última canción reproducida y su posición
  Future<void> _loadLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('lastIndex');
    final lastPosition = prefs.getInt('lastPosition');
    
    if (lastIndex != null && lastIndex < _songs.length) {
      setState(() {
        _currentIndex = lastIndex;
        _position = lastPosition != null ? Duration(seconds: lastPosition) : Duration.zero;
      });
      // No reproducir automáticamente
    }
  }

  // Configura los listeners para los eventos del reproductor
  void _setupAudioListeners() {
    if (_audioPlayer == null) return;
    _cancelAudioListeners();
    _playerStateSub = _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });
    _durationSub = _audioPlayer!.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });
    _positionSub = _audioPlayer!.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
    _completeSub = _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
      _nextSong();
    });
  }

  // Solicita permisos de audio y escanea archivos si se otorgan
  Future<void> _requestAudioPermission() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    
    final status = await Permission.audio.request();
    if (status.isGranted) {
      await _scanAudioFiles();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // Busca archivos de audio en los directorios comunes del dispositivo
  Future<void> _scanAudioFiles() async {
    if (mounted) {
      setState(() => _isScanning = true);
    }
    
    final audioExtensions = {'.mp3', '.m4a', '.wav', '.ogg', '.flac', '.aac'};
    final musicDirs = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/WhatsApp/Media',
      '/storage/emulated/0/Android/media',
    ];

    final foundSongs = <File>[];

    for (final dirPath in musicDirs) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final file in dir.list(recursive: true)) {
            if (!mounted) return;
            final path = file.path.toLowerCase();
            final ext = path.substring(path.lastIndexOf('.'));
            if (file is File && audioExtensions.contains(ext)) {
              foundSongs.add(file);
            }
          }
        }
      } catch (e) {
        debugPrint('Error en $dirPath: $e');
      }
    }

    if (mounted) {
      setState(() {
        _songs = foundSongs;
        _filteredSongs = foundSongs;
        _isScanning = false;
      });
      _loadLastPlayed();
    }
  }

  // Filtra la lista de canciones según la búsqueda del usuario
  void _filterSongs(String query) {
    setState(() {
      _filteredSongs = _songs.where((song) => 
        _cleanSongName(song.path.split('/').last).toLowerCase()
          .contains(query.toLowerCase())
      ).toList();
      // Si la canción actual ya no está en la lista filtrada, limpiar el índice
      if (_currentIndex != null && (_currentIndex! >= _filteredSongs.length || !_filteredSongs.contains(_songs[_currentIndex!]))) {
        _currentIndex = null;
        _playerState = PlayerState.stopped;
      }
    });
  }

  // Reproduce la canción seleccionada por el usuario
  Future<void> _playSong(int index) async {
    try {
      final song = _filteredSongs[index];
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _cancelAudioListeners();
      }
      _createAudioPlayer();
      if (mounted) {
        setState(() {
          _currentIndex = index;
          _playerState = PlayerState.playing;
          _position = Duration.zero;
        });
      }
      await _audioPlayer!.play(
        DeviceFileSource(song.path),
        volume: 0.8,
        position: Duration.zero,
        mode: PlayerMode.mediaPlayer,
      );
      await _saveLastPlayed();
    } catch (e) {
      debugPrint('Error al reproducir: $e');
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
        });
      }
    }
  }

  // Pausa la reproducción actual
  Future<void> _pause() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.pause();
      await _audioPlayer!.dispose();
      _cancelAudioListeners();
      _audioPlayer = null;
    }
    if (mounted) {
      setState(() => _playerState = PlayerState.paused);
    }
    await _saveLastPlayed();
  }

  // Reanuda la reproducción de la canción actual
  Future<void> _resume() async {
    if (_currentIndex == null) return;
    await _playSong(_currentIndex!);
  }

  // Permite saltar a una posición específica de la canción
  Future<void> _seek(Duration position) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.seek(position);
      await _saveLastPlayed();
    }
  }

  // Avanza a la siguiente canción (o aleatoria si está activado)
  void _nextSong() {
    if (_currentIndex == null || _filteredSongs.isEmpty) return;
    
    int nextIndex;
    if (_isRandomMode) {
      nextIndex = _getRandomIndex();
    } else {
      nextIndex = (_currentIndex! + 1) % _filteredSongs.length;
    }
    
    _playSong(nextIndex);
  }

  // Retrocede a la canción anterior (o aleatoria si está activado)
  void _previousSong() {
    if (_currentIndex == null || _filteredSongs.isEmpty) return;
    
    int prevIndex;
    if (_isRandomMode) {
      prevIndex = _getRandomIndex();
    } else {
      prevIndex = (_currentIndex! - 1) % _filteredSongs.length;
    }
    
    _playSong(prevIndex);
  }

  // Obtiene un índice aleatorio para la reproducción aleatoria
  int _getRandomIndex() {
    final random = DateTime.now().millisecond % _filteredSongs.length;
    return random != _currentIndex ? random : _getRandomIndex();
  }

  // Activa o desactiva el modo aleatorio
  void _toggleRandomMode() {
    setState(() {
      _isRandomMode = !_isRandomMode;
    });
    _savePreferences();
  }

  // Marca o desmarca la canción actual como favorita
  void _toggleFavorite() {
    if (_currentIndex == null) return;
    
    final songPath = _filteredSongs[_currentIndex!].path;
    setState(() {
      if (_favorites.contains(songPath)) {
        _favorites.remove(songPath);
      } else {
        _favorites.add(songPath);
      }
    });
    _savePreferences();
  }

  
  // Formatea la duración en minutos y segundos
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Limpia y formatea el nombre del archivo de la canción para mostrarlo
  String _cleanSongName(String fileName) {
    final nameWithoutExtension = fileName.replaceAll(RegExp(r'\.(mp3|m4a|wav|ogg|flac|aac)$'), '');
    return nameWithoutExtension
        .replaceAll('_', ' ')
        .replaceAll('-', ' - ')
        .replaceAll('[', ' (')
        .replaceAll(']', ') ')
        .replaceAll('  ', ' ')
        .trim();
  }

  // Construye los controles de reproducción y la barra de progreso
  Widget _buildPlayerControls() {
    // Colores adaptados para modo oscuro
    final Color mainButtonColor = Colors.white;
    final Color accentButtonColor = Colors.blueAccent.shade100;
    final Color sliderActiveColor = Colors.blueAccent.shade100;
    final Color sliderInactiveColor = Colors.white24;
    final Color iconFavorite = Colors.redAccent.shade200;
    final Color iconRandomActive = Colors.blueAccent.shade100;
    final Color iconRandomInactive = Colors.white38;
    final Color textColor = Colors.white70;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentIndex != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _favorites.contains(_filteredSongs[_currentIndex!].path)
                        ? Icons.favorite
                        : Icons.favorite_border,
                      color: iconFavorite,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                  Expanded(
                    child: Text(
                      _cleanSongName(_filteredSongs[_currentIndex!].path.split('/').last),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isRandomMode ? Icons.shuffle : Icons.shuffle_on,
                      color: _isRandomMode ? iconRandomActive : iconRandomInactive,
                    ),
                    onPressed: _toggleRandomMode,
                  ),
                ],
              ),
            ),
          
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
              Expanded(
                child: Slider(
                  value: _duration.inSeconds > 0
                      ? _position.inSeconds.clamp(0, _duration.inSeconds).toDouble()
                      : 0.0,
                  min: 0,
                  max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                  onChanged: _duration.inSeconds > 0
                      ? (value) => _seek(Duration(seconds: value.toInt()))
                      : null,
                  activeColor: sliderActiveColor,
                  inactiveColor: sliderInactiveColor,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.fast_rewind, size: 30, color: mainButtonColor),
                onPressed: _previousSong,
                tooltip: 'Canción anterior',
              ),
              Container(
                decoration: BoxDecoration(
                  color: accentButtonColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentButtonColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _playerState == PlayerState.playing 
                        ? Icons.pause 
                        : Icons.play_arrow,
                    color: Colors.black,
                    size: 36,
                  ),
                  onPressed: _playerState == PlayerState.playing 
                      ? _pause 
                      : _resume,
                ),
              ),
              IconButton(
                icon: Icon(Icons.fast_forward, size: 30, color: mainButtonColor),
                onPressed: _nextSong,
                tooltip: 'Siguiente canción',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Botón para refrescar y buscar nuevas canciones en el dispositivo
  Widget _buildRefreshButton() {
    return IconButton(
      icon: _isScanning 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh, size: 26, color: Colors.white),
      onPressed: _isScanning ? null : _scanAudioFiles,
      tooltip: 'Buscar nuevas canciones',
    );
  }

  
  // Indicador visual de la canción en reproducción
  Widget _buildPlayingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_playerState == PlayerState.playing)
          const Icon(Icons.graphic_eq, color: Colors.blue, size: 20),
        const SizedBox(width: 8),
        Icon(
          _playerState == PlayerState.playing
              ? Icons.pause
              : Icons.play_arrow,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 10),
            Text('Reproductor Musical'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          _buildRefreshButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSongs,
              decoration: InputDecoration(
                hintText: 'Buscar canciones...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Cargando canciones...'),
                      ],
                    ),
                  )
                : _filteredSongs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_off, size: 50, color: Colors.grey),
                            const SizedBox(height: 20),
                            const Text('No se encontraron canciones'),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.search),
                              label: const Text('Buscar canciones'),
                              onPressed: _scanAudioFiles,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredSongs.length,
                        itemBuilder: (context, index) {
                          final song = _filteredSongs[index];
                          final isCurrent = _currentIndex == index;
                          final isFavorite = _favorites.contains(song.path);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: isCurrent
                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                : Theme.of(context).cardColor,
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isFavorite ? Icons.favorite : Icons.music_note,
                                  color: isFavorite
                                      ? Colors.red
                                      : (isCurrent
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[600]),
                                ),
                              ),
                              title: Text(
                                _cleanSongName(song.path.split('/').last),
                                style: TextStyle(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: const Text(
                                'Music',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              onTap: () => _playSong(index),
                              trailing: isCurrent
                                  ? _buildPlayingIndicator()
                                  : Icon(
                                      Icons.play_arrow,
                                      color: Theme.of(context).primaryColor,
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _currentIndex != null 
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPlayerControls(),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _cancelAudioListeners();
    _searchController.dispose();
    super.dispose();
  }
}