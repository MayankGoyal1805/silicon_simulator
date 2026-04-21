import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('RV64I instruction semantics', () {
    test('executes logical and shift instructions', () {
      final loaded = _load('''
        addi t0, zero, 12
        addi t1, zero, 10
        and t2, t0, t1
        or  s0, t0, t1
        xor s1, t0, t1
        slli s2, t1, 2
        srli s3, s2, 1
        ebreak
      ''');

      const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(_r(loaded, 't2'), 8);
      expect(_r(loaded, 's0'), 14);
      expect(_r(loaded, 's1'), 6);
      expect(_r(loaded, 's2'), 40);
      expect(_r(loaded, 's3'), 20);
    });

    test('executes signed and unsigned comparisons', () {
      final loaded = _load('''
        addi t0, zero, -1
        addi t1, zero, 1
        slt t2, t0, t1
        sltu s0, t0, t1
        slti s1, t0, 0
        sltiu s2, t0, 1
        ebreak
      ''');

      const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(_r(loaded, 't2'), 1);
      expect(_r(loaded, 's0'), 0);
      expect(_r(loaded, 's1'), 1);
      expect(_r(loaded, 's2'), 0);
    });

    test('executes word-sized RV64I operations with sign extension', () {
      final loaded = _load('''
        addi t0, zero, -1
        addiw t1, t0, 0
        slliw t2, t1, 1
        srliw s0, t1, 1
        sraiw s1, t1, 1
        ebreak
      ''');

      const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(loaded.state.registers.readSigned(registerIndex('t1')), -1);
      expect(loaded.state.registers.readSigned(registerIndex('t2')), -2);
      expect(_r(loaded, 's0'), 0x7fffffff);
      expect(loaded.state.registers.readSigned(registerIndex('s1')), -1);
    });

    test('executes signed byte loads', () {
      const project = SimulationProject(
        memoryInitBlocks: [
          MemoryInitBlock(address: 80, bytes: [0xff]),
        ],
        assemblySource: '''
          addi sp, zero, 80
          lb t0, 0(sp)
          lbu t1, 0(sp)
          ebreak
        ''',
      );
      final loaded = const ProgramLoader().load(project);

      const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(loaded.state.registers.readSigned(registerIndex('t0')), -1);
      expect(_r(loaded, 't1'), 255);
    });

    test('executes jal and jalr control flow', () {
      final loaded = _load('''
        jal ra, target
        addi t0, zero, 1
      target:
        addi t1, zero, 2
        jalr zero, 0(ra)
        ebreak
      ''');

      const ExecutionEngine().step(loaded.state, loaded.memory);
      expect(_r(loaded, 'ra'), 4);
      expect(loaded.state.pc, 8);

      const ExecutionEngine().step(loaded.state, loaded.memory);
      const ExecutionEngine().step(loaded.state, loaded.memory);
      expect(loaded.state.pc, 4);
    });
  });
}

LoadedProgram _load(String assembly) {
  return const ProgramLoader().load(
    SimulationProject(assemblySource: assembly),
  );
}

int _r(LoadedProgram loaded, String name) {
  return loaded.state.registers.read(registerIndex(name));
}
