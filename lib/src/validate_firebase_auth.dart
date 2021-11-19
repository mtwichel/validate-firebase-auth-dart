import 'dart:io';

import 'package:http/io_client.dart';
import 'package:meta/meta.dart';
import 'package:openid_client/openid_client.dart';
import 'package:http/http.dart' as http;

/// {@template firebase_auth_validator}
/// An object to validate JWTs from Firebase Auth.
///
/// #### Usage
/// Validating is easy! Just
///
/// 1. Create a `FirebaseAuthValidator()`
/// 2. Initialize with `validator.init()`
/// 3. Validate JWT with `validator.validate()`
///
/// ```dart
/// final jwt = '...';  // Generated with a client library and sent with the request
/// final validator = FirebaseAuthValidator();
/// await validator.init();
/// final idToken = await validator.validate(jwt);
/// ```
/// {@endtemplate}
class FirebaseAuthValidator {
  /// {macro firebase_auth_emulator}
  FirebaseAuthValidator({
    PlatformWrapper? platformWrapper,
    http.Client? httpClient,
    Client? seededClient,
  })  : _seededClient = seededClient,
        _platformWrapper = platformWrapper ?? PlatformWrapper(),
        _httpClient = httpClient ?? IOClient();

  final PlatformWrapper _platformWrapper;
  final http.Client _httpClient;

  /// ONLY INTENDED FOR INTERNAL USE, MADE PUBLIC FOR TESTING
  ///
  /// The OpenId client for validating tokens.
  @visibleForTesting
  Client? client;

  final Client? _seededClient;

  /// Initializes authenticator and sets the project id.
  /// Must be called before `validate` is called.
  ///
  /// Example
  /// ```dart
  /// final validator = FirebaseAuthValidator();
  /// await validator.init();
  /// // ready to call validator.validate(token)
  /// ```
  ///
  /// The project id will be automatically discovered if running on a
  /// Google Cloud service like Cloud Run or GCE, but you can manually
  /// specify the project id like so:
  /// ```dart
  /// final validator = FirebaseAuthValidator();
  /// await validator.init(projectId: 'PROJECT-ID');
  /// // ready to call validator.validate(token)
  /// ```
  Future<void> init({String? projectId}) async {
    if (_seededClient != null) {
      client = _seededClient;
    } else {
      final calculatedProjectId = projectId ??
          await currentProjectId(
            platformWrapper: _platformWrapper,
            httpClient: _httpClient,
          );
      final issuer =
          await Issuer.discover(Issuer.firebase(calculatedProjectId));
      client = Client(issuer, projectId!);
    }
  }

  /// Validates a given JWT from Firebase Auth.
  ///
  /// Example:
  /// ```dart
  /// final validator = FirebaseAuthValidator();
  /// await validator.init();
  /// final token = validator.validate(token)
  ///
  /// if (token.isVerified) {
  ///   // ... do authenticated stuff
  /// }
  /// ```
  Future<IdToken> validate(
    String token,
  ) async {
    assert(client != null);
    final credential = client!.createCredential(idToken: token);

    await for (var e in credential.validateToken()) {
      throw Exception('Validating ID token failed: $e');
    }

    if (!(credential.idToken.claims.subject.isNotEmpty &&
        credential.idToken.claims.subject.length <= 128)) {
      throw Exception(
        'ID token has "sub" (subject) claim which is not a valid uid',
      );
    }

    return credential.idToken;
  }
}

/// ONLY INTENDED FOR INTERNAL USE, MADE PUBLIC FOR TESTING
///
/// Returns the current project id if running on a Google Cloud service
/// like Cloud Run or GCE.
@visibleForTesting
Future<String> currentProjectId({
  required PlatformWrapper platformWrapper,
  required http.Client httpClient,
}) async {
  for (var envKey in _gcpProjectIdEnvironmentVariables) {
    final value = platformWrapper.environment[envKey];
    if (value != null) return value;
  }

  const host = 'http://metadata.google.internal';
  final url = Uri.parse('$host/computeMetadata/v1/project/project-id');

  try {
    final response = await httpClient.get(
      url,
      headers: {'Metadata-Flavor': 'Google'},
    );

    if (response.statusCode != 200) {
      throw HttpException(
        '${response.body} (${response.statusCode})',
        uri: url,
      );
    }

    return response.body;
  } on SocketException {
    stderr.writeln(
      '''
Could not connect to $host.
If not running on Google Cloud, one of these environment variables must be set
to the target Google Project ID:
${_gcpProjectIdEnvironmentVariables.join('\n')}
''',
    );
    rethrow;
  }
}

final _gcpProjectIdEnvironmentVariables = {
  'GCP_PROJECT',
  'GCLOUD_PROJECT',
  'CLOUDSDK_CORE_PROJECT',
  'GOOGLE_CLOUD_PROJECT',
};

/// ONLY INTENDED FOR INTERNAL USE, MADE PUBLIC FOR TESTING
///
/// Wraps static Platform methods for mocking
@visibleForTesting
class PlatformWrapper {
  /// ONLY INTENDED FOR INTERNAL USE, MADE PUBLIC FOR TESTING
  ///
  /// Wraps static Platform.envirnoment for testing
  @visibleForTesting
  Map<String, String> get environment => Platform.environment;
}
