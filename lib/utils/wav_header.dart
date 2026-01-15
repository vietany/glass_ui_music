import 'dart:io';
import 'dart:typed_data';

Future<void> addWavHeader(String path) async {
  File file = File(path);
  if (!await file.exists()) return;

  var bytes = await file.readAsBytes();
  int totalDataLen = bytes.length;
  int longSampleRate = 44100;
  int channels = 1;
  int byteRate = 44100 * 2;

  var header = Uint8List(44);
  var view = ByteData.view(header.buffer);

  _writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + totalDataLen, Endian.little);
  _writeString(view, 8, 'WAVE');
  _writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, longSampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  _writeString(view, 36, 'data');
  view.setUint32(40, totalDataLen, Endian.little);

  var newBytes = BytesBuilder();
  newBytes.add(header);
  newBytes.add(bytes);
  await file.writeAsBytes(newBytes.toBytes());
}

void _writeString(ByteData view, int offset, String value) {
  for (int i = 0; i < value.length; i++) {
    view.setUint8(offset + i, value.codeUnitAt(i));
  }
}
