import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openid_client/openid_client_io.dart';
import 'package:test/test.dart';
import 'package:validate_firebase_auth/src/validate_firebase_auth.dart';

class MockPlatformWrapper extends Mock implements PlatformWrapper {}

class MockClient extends Mock implements Client {}

class MockCredential extends Mock implements Credential {}

class MockIdToken extends Mock implements IdToken {}

class MockOpenIdClaims extends Mock implements OpenIdClaims {}

class MockHttpClient extends Mock implements http.Client {}

class MockHttpResponse extends Mock implements http.Response {}

class UriFake extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(UriFake());
  });

  late PlatformWrapper platformWrapper;
  late http.Client httpClient;
  late Client client;
  late Credential credential;
  late IdToken idToken;
  late OpenIdClaims claims;

  setUp(() {
    platformWrapper = MockPlatformWrapper();
    when(() => platformWrapper.environment).thenReturn(
      {
        'GCP_PROJECT': 'test-project-id',
      },
    );

    httpClient = MockHttpClient();

    credential = MockCredential();
    idToken = MockIdToken();
    claims = MockOpenIdClaims();

    when(() => credential.validateToken())
        .thenAnswer((_) => Stream.fromIterable([]));
    when(() => credential.idToken).thenReturn(idToken);
    when(() => idToken.claims).thenReturn(claims);
    when(() => claims.subject).thenReturn('subject');

    client = MockClient();

    when(() => client.createCredential(idToken: any(named: 'idToken')))
        .thenReturn(credential);
  });
  group('FirebaseAuthValidator', () {
    group('validate', () {
      test('calls validate token', () async {
        final validator = FirebaseAuthValidator(
          openIdClient: client,
        );
        await validator.init();
        await validator.validate('token');
        verify(() => credential.validateToken()).called(1);
      });

      test('throws exception when validate token throws error', () async {
        when(() => credential.validateToken()).thenAnswer(
          (_) => Stream.fromIterable(
            [Exception()],
          ),
        );

        final validator = FirebaseAuthValidator(
          openIdClient: client,
        );
        await validator.init();
        await expectLater(
          () => validator.validate('token'),
          throwsException,
        );
      });

      test('throws exception when uid is not valid', () async {
        when(() => claims.subject).thenReturn('');
        final validator = FirebaseAuthValidator(
          openIdClient: client,
        );
        await validator.init();
        await expectLater(
          () => validator.validate('token'),
          throwsException,
        );
      });
    });
    group('init', () {
      test('sets client if not provided', () async {
        final validator = FirebaseAuthValidator(
          platformWrapper: platformWrapper,
        );
        expect(validator.init(), completes);
      });
    });

    group('currentProjectId', () {
      test('returns correctly when an environment variable is set', () async {
        final projId = await currentProjectId(
          platformWrapper: platformWrapper,
          httpClient: httpClient,
        );
        expect(projId, 'test-project-id');
      });
      test('returns correctly when an environment variable is not set',
          () async {
        final response = MockHttpResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn('test-project-id');

        when(() => platformWrapper.environment).thenReturn({});
        when(() => httpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => response);

        final projId = await currentProjectId(
          platformWrapper: platformWrapper,
          httpClient: httpClient,
        );
        expect(projId, 'test-project-id');
      });

      test('throws HttpException when response code not 200', () async {
        final response = MockHttpResponse();
        when(() => response.statusCode).thenReturn(400);
        when(() => response.body).thenReturn('');

        when(() => platformWrapper.environment).thenReturn({});
        when(() => httpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => response);

        await expectLater(
          () => currentProjectId(
            platformWrapper: platformWrapper,
            httpClient: httpClient,
          ),
          throwsA(isA<HttpException>()),
        );
      });
      test('throws SocketException when http throws socket exception',
          () async {
        when(() => platformWrapper.environment).thenReturn({});
        when(() => httpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(const SocketException('oops'));

        await expectLater(
          () => currentProjectId(
            platformWrapper: platformWrapper,
            httpClient: httpClient,
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });

  group('PlatformWrapper', () {
    test('environment returns environment', () {
      expect(PlatformWrapper().environment, isNotNull);
    });
  });
}
