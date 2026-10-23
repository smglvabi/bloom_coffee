import 'dart:async';
import 'dart:js_interop';
import 'dart:ui';
import 'package:web/web.dart' as web;

Future<void> exportJournal(String json, Rect? origin) async {
  final blob = web.Blob(
    [json.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = 'bloom-journal.json';
  web.document.body!.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
