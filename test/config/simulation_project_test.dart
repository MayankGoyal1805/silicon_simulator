import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/silicon_simulator.dart';

void main() {
  group('SimulationProject.validate', () {
    test('accepts the default phase 1 project', () {
      const project = SimulationProject();

      expect(project.validate(), isEmpty);
    });

    test('rejects unsupported ISA values', () {
      const project = SimulationProject(isa: 'rv32i');

      expect(project.validate(), contains('Phase 1 only supports rv64i.'));
    });

    test('rejects memory init blocks outside memory', () {
      const project = SimulationProject(
        memorySizeBytes: 4,
        memoryInitBlocks: [
          MemoryInitBlock(address: 2, bytes: [1, 2, 3]),
        ],
      );

      expect(
        project.validate(),
        contains('Memory init block extends beyond memory.'),
      );
    });

    test('serializes and deserializes project JSON', () {
      const project = SimulationProject(
        memorySizeBytes: 128,
        loadAddress: 16,
        entryPoint: 20,
        assemblySource: 'addi t0, zero, 1',
        registerOverrides: {'sp': 64, 'a0': 3},
        memoryInitBlocks: [
          MemoryInitBlock(address: 80, bytes: [1, 2, 3, 4]),
        ],
      );

      final encoded = project.toJsonString();
      final decoded = SimulationProject.fromJsonString(encoded);

      expect(decoded.memorySizeBytes, 128);
      expect(decoded.loadAddress, 16);
      expect(decoded.entryPoint, 20);
      expect(decoded.assemblySource, 'addi t0, zero, 1');
      expect(decoded.registerOverrides['sp'], 64);
      expect(decoded.registerOverrides['a0'], 3);
      expect(decoded.memoryInitBlocks.single.address, 80);
      expect(decoded.memoryInitBlocks.single.bytes, [1, 2, 3, 4]);
    });
  });
}
