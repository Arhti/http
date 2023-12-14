import 'package:http/http.dart';

void main() async {
  var url = Uri.parse(
      'https://archive.org/download/robinson-crusoe-daniel-defoe/Robinson%20Crusoe_Daniel%20Defoe.pdf');

  final progress = HttpProgress.withRecorder(print);

  var request = await get(url, downloadProgress: progress);

  print('Response status: ${request.statusCode}');
}
