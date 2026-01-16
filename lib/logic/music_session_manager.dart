import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'; // Để dùng ChangeNotifier
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../utils/audio_analyzer.dart';
import '../utils/wav_header.dart';

class MusicSessionManager extends ChangeNotifier {
  // --- CORE COMPONENTS ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  // --- PUBLIC DATA (UI sẽ đọc cái này) ---
  bool isRecording = false;
  bool isPlaying = false;
  double currentVolume = 0.0;
  List<MusicNote> notes = [];
  List<double> pitchHistory = [];
  Duration currentPlaybackPosition = Duration.zero;
  String lastWords = "";

  // --- PRIVATE VARS ---
  StreamSubscription? _audioSub;
  StreamSubscription? _playerSub;
  IOSink? _fileSink;
  String? _recordedFilePath;
  List<String> _wordBuffer = [];
  DateTime? _noteStartTime;
  MusicNote? _pendingNote;
  String _localeId = 'vi_VN';

  // Callback để báo UI cuộn màn hình (Scroll)
  Function(double position)? onScrollRequest;

  // --- INIT & DISPOSE ---
  Future<void> init() async {
    await _speechToText.initialize(onError: (e) => debugPrint("STT Err: $e"));
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _audioSub?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }

  void setLocale(String locale) {
    _localeId = locale;
    notifyListeners();
  }

  // --- LOGIC GHI ÂM ---
  Future<void> startRecording() async {
    if (await Permission.microphone.request() != PermissionStatus.granted) return;

    await _audioPlayer.stop();
    _resetState();
    isRecording = true;
    notifyListeners();

    // 1. Start STT
    if (_speechToText.isAvailable) {
      await _speechToText.listen(
        onResult: (res) {
          String newWords = res.recognizedWords;
          if (newWords.length > lastWords.length) {
            String added = newWords.substring(lastWords.length).trim();
            if (added.isNotEmpty) _wordBuffer.addAll(added.split(" "));
          }
          lastWords = newWords;
          notifyListeners(); // Cập nhật UI hiển thị lời
        },
        localeId: _localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onDevice: false, // Ép dùng Online
        listenMode: stt.ListenMode.dictation,
      );
    }

    // 2. Start Audio Recorder
    final dir = await getApplicationDocumentsDirectory();
    _recordedFilePath = '${dir.path}/session.wav';
    File(_recordedFilePath!).openWrite().close(); // Clear file
    _fileSink = File(_recordedFilePath!).openWrite();

    final stream = await _audioRecorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 44100, numChannels: 1)
    );

    DateTime recStart = DateTime.now();

    _audioSub = stream.listen((chunk) {
      _fileSink?.add(chunk);
      var result = AudioAnalyzer.analyzeChunk(chunk, 50);

      currentVolume = result['volume'];
      if (pitchHistory.length > 100) pitchHistory.removeAt(0);
      pitchHistory.add(result['pitch']);

      _processNoteLogic(result['note'], recStart);
      notifyListeners(); // Cập nhật UI liên tục (Volume, Pitch, Note)
    });
  }

  void _processNoteLogic(MusicNote? rawNote, DateTime recStart) {
    DateTime now = DateTime.now();
    if (currentVolume > 0.05 && rawNote != null) {
      if (_pendingNote == null) {
        _startNewNote(rawNote, now, recStart);
      } else if (rawNote.name != _pendingNote!.name) {
        _finalizeNote(now);
        _startNewNote(rawNote, now, recStart);
      }
    } else {
      if (_pendingNote != null && now.difference(_noteStartTime!).inMilliseconds > 100) {
        _finalizeNote(now);
      }
    }
  }

  void _startNewNote(MusicNote raw, DateTime now, DateTime recStart) {
    _pendingNote = MusicNote(raw.name, raw.position, NoteType.quarter, _popWord(), now.difference(recStart));
    _noteStartTime = now;
  }

  void _finalizeNote(DateTime endTime) {
    if (_pendingNote == null) return;
    Duration dur = endTime.difference(_noteStartTime!);

    if (dur.inMilliseconds > 1500) _pendingNote!.type = NoteType.whole;
    else if (dur.inMilliseconds > 750) _pendingNote!.type = NoteType.half;
    else if (dur.inMilliseconds > 375) _pendingNote!.type = NoteType.quarter;
    else if (dur.inMilliseconds > 180) _pendingNote!.type = NoteType.eighth;
    else _pendingNote!.type = NoteType.sixteenth;

    _pendingNote!.duration = dur;
    notes.add(_pendingNote!);

    // Yêu cầu UI cuộn
    onScrollRequest?.call(notes.length * 60.0 + 200);

    _pendingNote = null;
  }

  String _popWord() => _wordBuffer.isNotEmpty ? _wordBuffer.removeAt(0) : "";

  Future<void> stopRecording() async {
    await _audioRecorder.stop();
    await _audioSub?.cancel();
    await _fileSink?.close();
    await _speechToText.stop();
    if (_recordedFilePath != null) await addWavHeader(_recordedFilePath!);

    isRecording = false;
    currentVolume = 0.0;
    _pendingNote = null;
    notifyListeners();
  }

  // --- LOGIC PHÁT NHẠC ---
  Future<void> togglePlayback() async {
    if (_recordedFilePath == null) return;

    if (isPlaying) {
      await _audioPlayer.pause();
      isPlaying = false;
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      isPlaying = true;

      _playerSub = _audioPlayer.onPositionChanged.listen((p) {
        currentPlaybackPosition = p;
        // Logic tính vị trí để cuộn
        double cursorX = 50.0 + (notes.indexWhere((n) => n.startTime > p) * 60.0);
        if (cursorX > 0) onScrollRequest?.call(cursorX);
        notifyListeners();
      });

      _audioPlayer.onPlayerComplete.listen((e) {
        isPlaying = false;
        currentPlaybackPosition = Duration.zero;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void clear() {
    notes.clear();
    pitchHistory.clear();
    lastWords = "";
    notifyListeners();
  }

  void _resetState() {
    notes.clear();
    pitchHistory.clear();
    currentVolume = 0.0;
    _wordBuffer.clear();
    lastWords = "";
    currentPlaybackPosition = Duration.zero;
    _pendingNote = null;
  }
}