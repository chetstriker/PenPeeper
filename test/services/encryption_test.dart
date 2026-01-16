import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/services/export_import/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    final service = EncryptionService();

    test('should encrypt and decrypt data', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      const password = 'testPassword123';

      final encrypted = await service.encrypt(data, password);
      final decrypted = await service.decrypt(encrypted, password);

      expect(decrypted, equals(data));
    });

    test('should fail with wrong password', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final encrypted = await service.encrypt(data, 'password1');

      expect(
        () async => await service.decrypt(encrypted, 'password2'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should generate unique salts', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      const password = 'testPassword';

      final encrypted1 = await service.encrypt(data, password);
      final encrypted2 = await service.encrypt(data, password);

      final salt1 = encrypted1.sublist(0, 32);
      final salt2 = encrypted2.sublist(0, 32);

      expect(salt1, isNot(equals(salt2)));
    });



    test('should handle large data', () async {
      final data = Uint8List.fromList(List.generate(10000, (i) => i % 256));
      const password = 'testPassword';

      final encrypted = await service.encrypt(data, password);
      final decrypted = await service.decrypt(encrypted, password);

      expect(decrypted, equals(data));
    });
  });
}
