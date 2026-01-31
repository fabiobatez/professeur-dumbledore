import 'package:record/record.dart';

class Recorder {
  final Record _inner = Record();

  Future<bool> hasPermission() async {
    return await _inner.hasPermission();
  }

  Future<void> start() async {
    await _inner.start(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      samplingRate: 16000,
    );
  }

  Future<String?> stop() async {
    return await _inner.stop();
  }
}