import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<String?> readPickedFileText(PlatformFile file) async {
  try {
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes);
  } on Object {
    return null;
  }
}
