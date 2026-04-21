import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('ExecutionEngine', () {
    test('runs a small arithmetic program from assembly', () {
      const project = SimulationProject(
        assemblySource: '''
          addi t0, zero, 5
          addi t1, zero, 7
          add t2, t0, t1
          ebreak
        ''',
      );

      final loaded = const ProgramLoader().load(project);
      final result = const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(result.halted, isTrue);
      expect(result.steps, 4);
      expect(loaded.state.status, CpuStatus.halted);
      expect(loaded.state.registers.read(registerIndex('t2')), 12);
    });

    test('stores and loads doublewords', () {
      const project = SimulationProject(
        assemblySource: '''
          addi sp, zero, 64
          addi t0, zero, 42
          sd t0, 0(sp)
          ld t1, 0(sp)
          ebreak
        ''',
      );

      final loaded = const ProgramLoader().load(project);
      const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(loaded.state.registers.read(registerIndex('t1')), 42);
      expect(loaded.memory.readUint64LittleEndian(64), 42);
    });

    test('branches using labels', () {
      const project = SimulationProject(
        assemblySource: '''
          addi t0, zero, 3
        loop:
          addi t0, t0, -1
          bne t0, zero, loop
          addi t1, zero, 9
          ebreak
        ''',
      );

      final loaded = const ProgramLoader().load(project);
      const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(loaded.state.registers.read(registerIndex('t0')), 0);
      expect(loaded.state.registers.read(registerIndex('t1')), 9);
    });

    test('returns a trapped result instead of throwing simulator errors', () {
      const project = SimulationProject(
        assemblySource: '''
          addi sp, zero, 3
          ld t0, 0(sp)
        ''',
      );

      final loaded = const ProgramLoader().load(project);
      final result = const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(result.trapped, isTrue);
      expect(result.lastStep?.error?.kind, SimErrorKind.misalignedAccess);
      expect(loaded.state.status, CpuStatus.trapped);
    });

    test('reports when run stops because of the step limit', () {
      const project = SimulationProject(
        assemblySource: '''
        loop:
          jal zero, loop
        ''',
      );

      final loaded = const ProgramLoader().load(project);
      final result = const ExecutionEngine().run(
        loaded.state,
        loaded.memory,
        maxSteps: 3,
      );

      expect(result.stoppedBecauseStepLimit, isTrue);
      expect(result.steps, 3);
      expect(loaded.state.status, CpuStatus.running);
    });

    test('treats fence as a phase 1 no-op', () {
      const project = SimulationProject(
        assemblySource: '''
          addi t0, zero, 1
          fence
          addi t0, t0, 1
          ebreak
        ''',
      );

      final loaded = const ProgramLoader().load(project);
      final result = const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(result.halted, isTrue);
      expect(loaded.state.registers.read(registerIndex('t0')), 2);
    });

    test('reports ecall as a structured environment-call trap', () {
      const project = SimulationProject(assemblySource: 'ecall');

      final loaded = const ProgramLoader().load(project);
      final result = const ExecutionEngine().run(loaded.state, loaded.memory);

      expect(result.trapped, isTrue);
      expect(result.lastStep?.error?.kind, SimErrorKind.environmentCall);
      expect(loaded.state.status, CpuStatus.trapped);
    });
  });
}
