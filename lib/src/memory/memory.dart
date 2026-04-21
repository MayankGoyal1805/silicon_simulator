import '../errors/sim_error.dart';

class Memory {
  Memory(int sizeBytes) : _bytes = List<int>.filled(sizeBytes, 0) {
    if (sizeBytes <= 0) {
      throw const SimException(
        SimErrorKind.invalidProject,
        'Memory size must be positive.',
      );
    }
  }

  final List<int> _bytes;
  static final BigInt _twoTo64 = BigInt.one << 64;
  static final BigInt _signBit64 = BigInt.one << 63;

  int get sizeBytes => _bytes.length;

  int readByte(int address) {
    _checkRange(address, 1);
    return _bytes[address];
  }

  void writeByte(int address, int value) {
    _checkRange(address, 1);
    _bytes[address] = value & 0xff;
  }

  int readUint16LittleEndian(int address) {
    _checkAligned(address, 2);
    final b0 = readByte(address);
    final b1 = readByte(address + 1);
    return b0 | (b1 << 8);
  }

  int readUint32LittleEndian(int address) {
    _checkAligned(address, 4);
    final b0 = readByte(address);
    final b1 = readByte(address + 1);
    final b2 = readByte(address + 2);
    final b3 = readByte(address + 3);
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
  }

  int readUint64LittleEndian(int address) {
    _checkAligned(address, 8);
    var value = 0;
    for (var i = 0; i < 8; i++) {
      value |= readByte(address + i) << (8 * i);
    }
    return _normalizeSigned64(value);
  }

  void writeUint16LittleEndian(int address, int value) {
    _checkAligned(address, 2);
    for (var i = 0; i < 2; i++) {
      writeByte(address + i, value >> (8 * i));
    }
  }

  void writeUint32LittleEndian(int address, int value) {
    _checkAligned(address, 4);
    for (var i = 0; i < 4; i++) {
      writeByte(address + i, value >> (8 * i));
    }
  }

  void writeUint64LittleEndian(int address, int value) {
    _checkAligned(address, 8);
    var normalized = BigInt.from(value) % _twoTo64;
    if (normalized.isNegative) {
      normalized += _twoTo64;
    }
    for (var i = 0; i < 8; i++) {
      writeByte(address + i, (normalized >> (8 * i)).toInt());
    }
  }

  void writeBytes(int address, List<int> bytes) {
    _checkRange(address, bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      writeByte(address + i, bytes[i]);
    }
  }

  List<int> slice(int address, int length) {
    _checkRange(address, length);
    return List<int>.unmodifiable(_bytes.getRange(address, address + length));
  }

  void _checkRange(int address, int width) {
    if (address < 0 || width < 0 || address + width > _bytes.length) {
      throw SimException(
        SimErrorKind.memoryAccess,
        'Memory access is outside the configured memory range.',
        address: address,
      );
    }
  }

  void _checkAligned(int address, int alignment) {
    if (address % alignment != 0) {
      throw SimException(
        SimErrorKind.misalignedAccess,
        'Address must be aligned to $alignment bytes.',
        address: address,
      );
    }
  }

  static int _normalizeSigned64(int value) {
    var normalized = BigInt.from(value) % _twoTo64;
    if (normalized.isNegative) {
      normalized += _twoTo64;
    }
    if (normalized >= _signBit64) {
      normalized -= _twoTo64;
    }
    return normalized.toInt();
  }
}
