import 'package:flutter/services.dart';

Future<String> saveEventExportContents(String csv) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return 'Export copied to clipboard (web has no local file save).';
}
