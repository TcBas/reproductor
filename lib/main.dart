import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reproductor de Música',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MusicPlayerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<File> _songs = [];
  bool _loading = false;
  int? _currentIndex;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _requestAudioPermission();
  }

  void _setupAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
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
    if (!mounted) return;
    
    setState(() => _loading = true);
    
    try {
      final status = await Permission.audio.request();
      if (status.isGranted) {
        await _scanAudioFiles();
      }
    } catch (e) {
      debugPrint('Error en permisos: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanAudioFiles() async {
    final audioExtensions = {'.mp3', '.m4a', '.wav', '.ogg', '.flac', '.aac'};
    final musicDirs = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
    ];

    final foundSongs = <File>[];

    try {
      for (final dirPath in musicDirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final file in dir.list(recursive: true)) {
            try {
              final path = file.path.toLowerCase();
              if (file is File && path.contains('.')) {
                final ext = path.substring(path.lastIndexOf('.'));
                if (audioExtensions.contains(ext)) {
                  foundSongs.add(file);
                }
              }
            } catch (e) {
              debugPrint('Error procesando archivo: ${file.path} - $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error escaneando archivos: $e');
    }

    if (mounted) setState(() => _songs = foundSongs);
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length || !mounted) return;

    try {
      await _audioPlayer.stop();
      final song = _songs[index];
      
      setState(() {
        _currentIndex = index;
        _playerState = PlayerState.playing;
        _position = Duration.zero;
      });

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setPlaybackRate(1.0);
      await _audioPlayer.play(DeviceFileSource(song.path));
    } catch (e) {
      debugPrint('Error al reproducir: $e');
      if (mounted) setState(() => _playerState = PlayerState.stopped);
    }
  }

  Future<void> _pause() async {
    try {
      await _audioPlayer.pause();
      if (mounted) setState(() => _playerState = PlayerState.paused);
    } catch (e) {
      debugPrint('Error al pausar: $e');
    }
  }

  Future<void> _resume() async {
    try {
      await _audioPlayer.resume();
      if (mounted) setState(() => _playerState = PlayerState.playing);
    } catch (e) {
      debugPrint('Error al reanudar: $e');
      if (_currentIndex != null) _playSong(_currentIndex!);
    }
  }

  Future<void> _seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Error al buscar posición: $e');
    }
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

  Widget _buildPlayerControls() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
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
        children: [
          if (_currentIndex != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                _songs[_currentIndex!].path.split('/').last,
                style: TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            children: [
              Text(_formatDuration(_position)),
              Expanded(
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  min: 0,
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) => _seek(Duration(seconds: value.toInt())),
                ),
              ),
              Text(_formatDuration(_duration)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous),
                onPressed: _previousSong,
              ),
              IconButton(
                icon: Icon(
                  _playerState == PlayerState.playing 
                      ? Icons.pause 
                      : Icons.play_arrow,
                ),
                onPressed: _playerState == PlayerState.playing 
                    ? _pause 
                    : _resume,
              ),
              IconButton(
                icon: Icon(Icons.skip_next),
                onPressed: _nextSong,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reproductor de Música'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _audioPlayer.stop();
              _scanAudioFiles();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(child: Text('No se encontraron canciones'))
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      title: Text(song.path.split('/').last),
                      onTap: () => _playSong(index),
                      selected: _currentIndex == index,
                    );
                  },
                ),
      bottomNavigationBar: _currentIndex != null 
          ? _buildPlayerControls()
          : null,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}