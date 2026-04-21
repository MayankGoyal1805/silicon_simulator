import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('SimulatorRuntime', () {
    test('loads a project and exposes an initial snapshot', () {
      final runtime = SimulatorRuntime.load(
        const SimulationProject(
          memorySizeBytes: 128,
          registerOverrides: {'sp': 64},
          assemblySource: 'ebreak',
        ),
      );

      final snapshot = runtime.snapshot(memoryStart: 0, memoryLength: 8);

      expect(snapshot.machine.pc, 0);
      expect(snapshot.machine.registers[registerIndex('sp')], 64);
      expect(snapshot.memoryBytes, hasLength(8));
      expect(snapshot.lastStep, isNull);
    });

    test('steps and records the last step result', () {
      final runtime = SimulatorRuntime.load(
        const SimulationProject(
          assemblySource: '''
            addi t0, zero, 11
            ebreak
          ''',
        ),
      );

      final result = runtime.step();
      final snapshot = runtime.snapshot();

      expect(result.succeeded, isTrue);
      expect(snapshot.lastStep, same(result));
      expect(snapshot.machine.registers[registerIndex('t0')], 11);
    });

    test('reset reloads the original project state', () {
      final runtime = SimulatorRuntime.load(
        const SimulationProject(
          assemblySource: '''
            addi t0, zero, 11
            ebreak
          ''',
        ),
      );

      runtime.step();
      final resetRuntime = runtime.reset();

      expect(runtime.state.registers.read(registerIndex('t0')), 11);
      expect(resetRuntime.state.registers.read(registerIndex('t0')), 0);
      expect(resetRuntime.state.pc, 0);
    });
  });
}
