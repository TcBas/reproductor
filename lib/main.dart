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

  @override
  void initState() {
    super.initState();
    _requestAudioPermission();
  }

  Future<void> _requestAudioPermission() async {
    setState(() => _loading = true);
    
    // Solo solicita permiso para audio
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reproductor de Audio')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(child: Text('No se encontraron archivos de audio'))
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      title: Text(song.path.split('/').last),
                      onTap: () => _audioPlayer.play(DeviceFileSource(song.path)),
                    );
                  },
                ),
    );
  }
}