import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MusicPlayerScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.loop)
    ..setVolume(0.8);
  
  List<File> _songs = [];
  bool _loading = false;
  int? _currentIndex;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
    _requestAudioPermission();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
      _nextSong();
    });
  }

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

  Future<void> _scanAudioFiles() async {
    if (mounted) {
      setState(() => _isScanning = true);
    }
    
    final audioExtensions = {'.mp3', '.m4a', '.wav', '.ogg', '.flac', '.aac'};
    final musicDirs = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
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
        _isScanning = false;
      });
    }
  }

  Future<void> _playSong(int index) async {
    try {
      final song = _songs[index];
      await _audioPlayer.stop();
      
      if (mounted) {
        setState(() {
          _currentIndex = index;
          _playerState = PlayerState.playing;
          _position = Duration.zero;
        });
      }
      
      await _audioPlayer.play(
        DeviceFileSource(song.path),
        volume: 0.8,
        position: Duration.zero,
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      debugPrint('Error al reproducir: $e');
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
        });
      }
    }
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
    if (mounted) {
      setState(() => _playerState = PlayerState.paused);
    }
  }

  Future<void> _resume() async {
    try {
      await _audioPlayer.resume();
      if (mounted) {
        setState(() => _playerState = PlayerState.playing);
      }
    } catch (e) {
      if (_currentIndex != null) {
        await _playSong(_currentIndex!);
      }
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _nextSong() {
    if (_currentIndex == null || _songs.isEmpty) return;
    final nextIndex = (_currentIndex! + 1) % _songs.length;
    _playSong(nextIndex);
  }

  void _previousSong() {
    if (_currentIndex == null || _songs.isEmpty) return;
    final prevIndex = (_currentIndex! - 1) % _songs.length;
    _playSong(prevIndex);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

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

  Widget _buildPlayerControls() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
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
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.music_note, size: 16, color: Theme.of(context).primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cleanSongName(_songs[_currentIndex!].path.split('/').last),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Expanded(
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  min: 0,
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) => _seek(Duration(seconds: value.toInt())),
                  activeColor: Theme.of(context).primaryColor,
                  inactiveColor: Colors.grey[300],
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.fast_rewind, size: 30, color: Theme.of(context).primaryColor),
                onPressed: _previousSong,
                tooltip: 'Canción anterior',
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: _playerState == PlayerState.playing 
                      ? _pause 
                      : _resume,
                ),
              ),
              IconButton(
                icon: Icon(Icons.fast_forward, size: 30, color: Theme.of(context).primaryColor),
                onPressed: _nextSong,
                tooltip: 'Siguiente canción',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: _isScanning 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(Icons.refresh, size: 26, color: Colors.white),
      onPressed: _isScanning ? null : _scanAudioFiles,
      tooltip: 'Buscar nuevas canciones',
    );
  }

  Widget _buildPlayingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_playerState == PlayerState.playing)
          Icon(Icons.graphic_eq, color: Colors.blue, size: 20),
        SizedBox(width: 8),
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 10),
            Text('Reproductor Musical'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [_buildRefreshButton()],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Cargando canciones...'),
                ],
              ),
            )
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 50, color: Colors.grey),
                      SizedBox(height: 20),
                      Text('No se encontraron canciones'),
                      SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: Icon(Icons.search),
                        label: Text('Buscar canciones'),
                        onPressed: _scanAudioFiles,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: _currentIndex == index 
                          ? Theme.of(context).primaryColor.withOpacity(0.1) 
                          : Theme.of(context).cardColor,
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _currentIndex == index 
                                ? Theme.of(context).primaryColor.withOpacity(0.2) 
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.music_note,
                            color: _currentIndex == index 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey[600],
                          ),
                        ),
                        title: Text(
                          _cleanSongName(song.path.split('/').last),
                          style: TextStyle(
                            fontWeight: _currentIndex == index 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'Music',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () => _playSong(index),
                        trailing: _currentIndex == index
                            ? _buildPlayingIndicator()
                            : Icon(
                                Icons.play_arrow,
                                color: Theme.of(context).primaryColor,
                              ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _currentIndex != null 
          ? Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _buildPlayerControls(),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}