class RegisterFile {
  RegisterFile() : _values = List<int>.filled(registerCount, 0);

  static const registerCount = 32;
  static final BigInt _twoTo64 = BigInt.one << 64;
  static final BigInt _signBit64 = BigInt.one << 63;

  final List<int> _values;

  int read(int index) {
    _checkIndex(index);
    return _values[index];
  }

  int readSigned(int index) => _toSigned64(read(index));

  void write(int index, int value) {
    _checkIndex(index);
    if (index == 0) {
      return;
    }
    _values[index] = _normalizeSigned64(value);
  }

  List<int> snapshot() => List<int>.unmodifiable(_values);

  void _checkIndex(int index) {
    if (index < 0 || index >= registerCount) {
      throw RangeError.range(index, 0, registerCount - 1, 'index');
    }
  }

  static int _toSigned64(int value) {
    return _normalizeSigned64(value);
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
