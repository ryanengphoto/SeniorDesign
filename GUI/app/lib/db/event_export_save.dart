import 'event_export_save_io.dart'
    if (dart.library.html) 'event_export_save_web.dart' as impl;

Future<String> saveEventExportContents(String csv) =>
    impl.saveEventExportContents(csv);
