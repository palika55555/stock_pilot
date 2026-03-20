import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Desktop implementácia – uloží PDF do Documents a otvorí ho.
Future<void> saveAndOpenPdf(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  if (Platform.isWindows) {
    await Process.run('start', ['', file.path], runInShell: true);
  } else if (Platform.isMacOS) {
    await Process.run('open', [file.path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [file.path]);
  }
}
