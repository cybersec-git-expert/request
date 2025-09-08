import 'dart:convert';
import 'package:http/http.dart' as http;
import 'src/services/api_client.dart';

Future<void> main() async {
  final api = ApiClient.instance;
  final token = await api.getToken();
  print('token_present=' + ((token!=null&&token.isNotEmpty).toString()));
  final base = ApiClient.baseUrlPublic;
  final resp = await http.get(Uri.parse('/api/flutter/subscriptions/membership-init'), headers: {
    'Content-Type':'application/json', if (token!=null) 'Authorization':'Bearer '+token
  });
  print('status=' + resp.statusCode.toString());
  print('body=' + resp.body.substring(0, resp.body.length>400?400:resp.body.length));
}