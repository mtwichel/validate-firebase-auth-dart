# validate_firebase_auth

[![Pub](https://img.shields.io/pub/v/validate-firebase-auth.svg)](https://pub.dev/packages/validate-firebase-auth)
[![build](https://github.com/mtwichel/validate-firebase-auth-dart/workflows/validate_firebase_auth/badge.svg)](https://github.com/mtwichel/validate-firebase-auth-dart/actions)
[![coverage](https://raw.githubusercontent.com/mtwichel/validate-firebase-auth-dart/main/coverage_badge.svg)](https://github.com/mtwichel/validate-firebase-auth-dart/actions)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A small package that verifies Firebase Auth Tokens when writing server-side Dart code. Perfect for use with the [Dart Functions Framework](https://pub.dev/packages/functions_framework)!

The validation follows [these steps](https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library), and validation is done with the [openid_client](https://pub.dev/packages/openid_client) package. Give their repo a star along with this one if you find this package useful! Their package does all the heavy cryptography lifting!

## Getting Started

Validating is easy! Just

1. Create a `FirebaseAuthValidator()`
2. Initialize with `validator.init()`
3. Validate JWT with `validator.validate()`

```dart
final jwt = '...';  // Generated with a client library and sent with the request
final validator = FirebaseAuthValidator();
await validator.init();
final idToken = await validator.validate(jwt);
```

## Specifiying Project Id

If you are running this code on a Google Cloud service (like Cloud Run or GCE), the project id will discovered automatically when you run `validator.init() `. You can specify a project id manually using `validator.init(projectId: projectId)`

## Using in Tests

You can easily mock a `FirebaseAuthValidator` using [mocktail](https://pub.dev/packages/mocktail), the type safe and null safe tool for mocking objects in tests. For example:

```dart
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuthValidator extends Mock implements FirebaseAuthValidator { }

class MockIdToken extends Mock implements IdToken { }

void main() {
  late FirebaseAuthValidator validator;
  late IdToken token;

  setUp(() {
    validator = MockFirebaseAuthValidator();
    idToken = MockIdToken();

    when(() => validator.init()).thenAnswer((_) async => null);
    when(() => validator.validate()).thenAnswer((_) async => idToken);

    when(() => idToken.isVerified).thenReturn(true);
  });
}
```
