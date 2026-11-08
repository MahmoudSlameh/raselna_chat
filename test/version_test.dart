import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

void main() {
  test('X-Raselna-SDK version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(raselnaSdkVersion, version);
  });
}
