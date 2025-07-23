import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class ReproductorScreen extends StatefulWidget {
  final File song;
  final AudioPlayer audioPlayer;

  const ReproductorScreen({
    required this.song,
    required this.audioPlayer,
  });

  @override
  _ReproductorScreenState createState() => _ReproductorScreenState();
}

class _ReproductorScreenState extends State<ReproductorScreen> {
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _playSong();
  }

  Future<void> _playSong() async {
    await widget.audioPlayer.play(DeviceFileSource(widget.song.path));
    setState(() => _isPlaying = true);
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        widget.audioPlayer.resume();
      } else {
        widget.audioPlayer.pause();
      }
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
            Text(
              widget.song.path.split('/').last,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
              ),
              onPressed: _togglePlayPause,
            ),
          ],
        ),
      ),
    );
  }
}