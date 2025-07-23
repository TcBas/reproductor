import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class ReproductorScreen extends StatefulWidget {
  final File song;
  final AudioPlayer audioPlayer;
  final List<File> songList;       // Añade estos parámetros
  final int currentIndex;         // al constructor

  const ReproductorScreen({
    required this.song,
    required this.audioPlayer,
    required this.songList,      // Añadidos aquí
    required this.currentIndex,  // y aquí
  });

  @override
  _ReproductorScreenState createState() => _ReproductorScreenState();
}

class _ReproductorScreenState extends State<ReproductorScreen> {
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    widget.audioPlayer.play(DeviceFileSource(widget.song.path));
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? widget.audioPlayer.resume() : widget.audioPlayer.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reproduciendo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.song.path.split('/').last),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  onPressed: () {}, // Implementar luego
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: () {}, // Implementar luego
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}