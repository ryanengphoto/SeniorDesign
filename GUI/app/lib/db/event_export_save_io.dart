import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveEventExportContents(String csv) async {
  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')
      .first;
  final path = p.join(dir.path, 'hub_security_events_$stamp.csv');
  await File(path).writeAsString(csv);
  return 'Exported to $path';
}
