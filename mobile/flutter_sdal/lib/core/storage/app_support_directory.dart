import 'dart:io';

Future<Directory> getSdalAppSupportDirectory() async {
  final env = Platform.environment;
  String? basePath;

  if (Platform.isIOS || Platform.isMacOS) {
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      basePath = '$home/Library/Application Support';
    }
  } else if (Platform.isAndroid) {
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      basePath = home;
    }
  } else {
    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      basePath = home;
    }
  }

  final supportDir = Directory(
    basePath == null || basePath.isEmpty
        ? '${Directory.systemTemp.path}/flutter_sdal'
        : '$basePath/flutter_sdal',
  );
  await supportDir.create(recursive: true);
  return supportDir;
}
