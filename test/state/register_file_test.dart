import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('RegisterFile', () {
    test('starts with 32 zeroed registers', () {
      final registers = RegisterFile();

      expect(registers.snapshot(), hasLength(32));
      expect(registers.snapshot().every((value) => value == 0), isTrue);
    });

    test('ignores writes to x0', () {
      final registers = RegisterFile();

      registers.write(0, 99);

      expect(registers.read(0), 0);
    });

    test('stores writes as 64-bit values', () {
      final registers = RegisterFile();

      registers.write(1, -1);

      expect(registers.readSigned(1), -1);
    });
  });
}
