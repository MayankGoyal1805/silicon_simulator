import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('Rv64iDecoder', () {
    test('decodes addi', () {
      final program = const Assembler().assemble('addi t0, zero, 5');
      final word = _word(program.bytes);

      final instruction = const Rv64iDecoder().decode(word);

      expect(instruction.op, Rv64iOp.addi);
      expect(instruction.rd, 5);
      expect(instruction.rs1, 0);
      expect(instruction.immediate, 5);
    });

    test('decodes register add', () {
      final program = const Assembler().assemble('add t2, t0, t1');
      final word = _word(program.bytes);

      final instruction = const Rv64iDecoder().decode(word);

      expect(instruction.op, Rv64iOp.add);
      expect(instruction.rd, 7);
      expect(instruction.rs1, 5);
      expect(instruction.rs2, 6);
    });
  });
}

int _word(List<int> bytes) {
  return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
}
