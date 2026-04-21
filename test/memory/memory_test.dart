import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('Memory', () {
    test('starts zero-initialized', () {
      final memory = Memory(8);

      expect(memory.readByte(0), 0);
      expect(memory.readByte(7), 0);
    });

    test('stores only the low 8 bits on byte writes', () {
      final memory = Memory(8);

      memory.writeByte(0, 0x1ff);

      expect(memory.readByte(0), 0xff);
    });

    test('throws structured errors outside memory', () {
      final memory = Memory(8);

      expect(() => memory.readByte(8), throwsA(isA<SimException>()));
    });

    test('reads 32-bit values in little-endian order', () {
      final memory = Memory(8);
      memory.writeByte(0, 0x78);
      memory.writeByte(1, 0x56);
      memory.writeByte(2, 0x34);
      memory.writeByte(3, 0x12);

      expect(memory.readUint32LittleEndian(0), 0x12345678);
    });
  });
}
