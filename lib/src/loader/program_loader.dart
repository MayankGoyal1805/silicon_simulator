import '../assembler/assembler.dart';
import '../config/simulation_project.dart';
import '../memory/memory.dart';
import '../state/cpu_status.dart';
import '../state/machine_state.dart';
import '../state/register_file.dart';
import '../state/register_names.dart';

class LoadedProgram {
  const LoadedProgram({
    required this.state,
    required this.memory,
    required this.programBytes,
  });

  final MachineState state;
  final Memory memory;
  final List<int> programBytes;
}

class ProgramLoader {
  const ProgramLoader({this.assembler = const Assembler()});

  final Assembler assembler;

  LoadedProgram load(SimulationProject project) {
    project.validateOrThrow();

    final memory = Memory(project.memorySizeBytes);
    for (final block in project.memoryInitBlocks) {
      memory.writeBytes(block.address, block.bytes);
    }

    final program = assembler.assemble(
      project.assemblySource,
      baseAddress: project.loadAddress,
    );
    memory.writeBytes(project.loadAddress, program.bytes);

    final registers = RegisterFile();
    for (final entry in project.registerOverrides.entries) {
      registers.write(registerIndex(entry.key), entry.value);
    }

    return LoadedProgram(
      state: MachineState(
        pc: project.entryPoint,
        registers: registers,
        status: CpuStatus.ready,
      ),
      memory: memory,
      programBytes: program.bytes,
    );
  }
}
