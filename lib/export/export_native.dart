import 'dart:convert';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';

Future<void> exportJournal(String json, Rect? origin) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          utf8.encode(json),
          mimeType: 'application/json',
          name: 'bloom-journal.json',
        ),
      ],
      fileNameOverrides: ['bloom-journal.json'],
      title: 'Журнал Bloom',
      sharePositionOrigin: origin,
    ),
  );
}
