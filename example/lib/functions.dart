// ignore_for_file: public_member_api_docs

import 'package:functions_framework/functions_framework.dart';
import 'package:shelf/shelf.dart';
import 'package:validate_firebase_auth/validate_firebase_auth.dart';

@CloudFunction()
Future<Response> function(Request request) async {
  final authHeader = request.headers['Authentication'];

  if (authHeader == null) {
    return Response.forbidden('Authentication header not set.');
  }

  if (!authHeader.startsWith('Bearer ')) {
    return Response.forbidden('Authentication header malformed.');
  }

  final jwt = authHeader.split(' ')[1];

  final validator = FirebaseAuthValidator();
  await validator.init();

  final token = await validator.validate(jwt);

  return Response.ok(
    token.isVerified ?? false ? 'Token is valid' : 'Token not valid',
  );
}
