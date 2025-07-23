import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    _setupAudioListeners();
    _requestAudioPermission();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
      _nextSong();
    });
  }

  Future<void> _requestAudioPermission() async {
    setState(() => _loading = true);
    
    final status = await Permission.audio.request();
    if (status.isGranted) {
      await _scanAudioFiles();
    }

    setState(() => _loading = false);
  }

  Future<void> _scanAudioFiles() async {
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
            final ext = file.path.toLowerCase().substring(file.path.lastIndexOf('.'));
            if (file is File && audioExtensions.contains(ext)) {
              foundSongs.add(file);
            }
          }
        }
      } catch (e) {
        debugPrint('Error en $dirPath: $e');
      }
    }

    setState(() => _songs = foundSongs);
  }

  Future<void> _playSong(int index) async {
    final song = _songs[index];
    setState(() {
      _currentIndex = index;
      _playerState = PlayerState.playing;
      _position = Duration.zero;
    });
    await _audioPlayer.play(DeviceFileSource(song.path));
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
    setState(() => _playerState = PlayerState.paused);
  }

  Future<void> _resume() async {
    await _audioPlayer.resume();
    setState(() => _playerState = PlayerState.playing);
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre de la canción actual
          if (_currentIndex != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                _songs[_currentIndex!].path.split('/').last,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          // Barra de progreso
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  min: 0,
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) => _seek(Duration(seconds: value.toInt())),
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          
          // Controles principales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous, size: 28),
                onPressed: _previousSong,
                iconSize: 32,
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
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
                  ),
                  onPressed: _playerState == PlayerState.playing 
                      ? _pause 
                      : _resume,
                  iconSize: 36,
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_next, size: 28),
                onPressed: _nextSong,
                iconSize: 32,
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
        title: Text('Reproductor de Audio'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(child: Text('No se encontraron archivos de audio'))
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      title: Text(
                        song.path.split('/').last,
                        style: TextStyle(
                          fontWeight: _currentIndex == index 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () => _playSong(index),
                      selected: _currentIndex == index,
                      selectedTileColor: Colors.blue.withOpacity(0.1),
                      trailing: _currentIndex == index
                          ? Icon(
                              _playerState == PlayerState.playing
                                  ? Icons.equalizer
                                  : Icons.pause,
                              color: Colors.blue,
                            )
                          : null,
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