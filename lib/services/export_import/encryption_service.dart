import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class EncryptionService {
  static const int _saltLength = 32;
  static const int _ivLength = 16;
  static const int _iterations = 100000;

  Future<Uint8List> encrypt(Uint8List data, String password) async {
    final salt = _generateSalt();
    final key = _deriveKey(password, salt);
    final iv = IV.fromSecureRandom(_ivLength);
    
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    final result = BytesBuilder();
    result.add(salt);
    result.add(iv.bytes);
    result.add(encrypted.bytes);
    
    return result.toBytes();
  }

  Future<Uint8List> decrypt(Uint8List data, String password) async {
    if (data.length < _saltLength + _ivLength) {
      throw Exception('Invalid encrypted data');
    }
    
    final salt = data.sublist(0, _saltLength);
    final ivBytes = data.sublist(_saltLength, _saltLength + _ivLength);
    final encryptedData = data.sublist(_saltLength + _ivLength);
    
    final key = _deriveKey(password, salt);
    final iv = IV(ivBytes);
    
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(encryptedData), iv: iv);
    
    return Uint8List.fromList(decrypted);
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final pbkdf2 = Pbkdf2(iterations: _iterations, hashAlgorithm: sha256);
    return Uint8List.fromList(pbkdf2.generateKey(bytes, salt, 32));
  }

  Uint8List _generateSalt() {
    return Uint8List.fromList(List.generate(_saltLength, (_) => 
      DateTime.now().microsecondsSinceEpoch % 256));
  }
}

class Pbkdf2 {
  final int iterations;
  final Hash hashAlgorithm;

  Pbkdf2({required this.iterations, required this.hashAlgorithm});

  List<int> generateKey(List<int> password, List<int> salt, int keyLength) {
    final hmac = Hmac(hashAlgorithm, password);
    final blocks = (keyLength / hashAlgorithm.convert([]).bytes.length).ceil();
    final key = <int>[];

    for (var i = 1; i <= blocks; i++) {
      final block = _computeBlock(hmac, salt, i);
      key.addAll(block);
    }

    return key.sublist(0, keyLength);
  }

  List<int> _computeBlock(Hmac hmac, List<int> salt, int blockNumber) {
    final blockBytes = <int>[
      ...salt,
      (blockNumber >> 24) & 0xff,
      (blockNumber >> 16) & 0xff,
      (blockNumber >> 8) & 0xff,
      blockNumber & 0xff,
    ];

    var u = hmac.convert(blockBytes).bytes;
    final result = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    return result;
  }
}
