import '../config/simulation_project.dart';
import '../execute/execution_engine.dart';
import '../execute/execution_result.dart';
import '../loader/program_loader.dart';
import '../memory/memory.dart';
import '../state/machine_state.dart';

class SimulatorSnapshot {
  const SimulatorSnapshot({
    required this.machine,
    required this.memoryStart,
    required this.memoryBytes,
    required this.lastStep,
  });

  final MachineStateSnapshot machine;
  final int memoryStart;
  final List<int> memoryBytes;
  final StepResult? lastStep;
}

class SimulatorRuntime {
  SimulatorRuntime._({
    required this.project,
    required LoadedProgram loaded,
    required this.loader,
    required this.engine,
  }) : state = loaded.state,
       memory = loaded.memory,
       programBytes = loaded.programBytes;

  factory SimulatorRuntime.load(
    SimulationProject project, {
    ProgramLoader loader = const ProgramLoader(),
    ExecutionEngine engine = const ExecutionEngine(),
  }) {
    return SimulatorRuntime._(
      project: project,
      loaded: loader.load(project),
      loader: loader,
      engine: engine,
    );
  }

  final SimulationProject project;
  final ProgramLoader loader;
  final ExecutionEngine engine;
  final MachineState state;
  final Memory memory;
  final List<int> programBytes;

  StepResult? lastStep;

  StepResult step() {
    lastStep = engine.step(state, memory);
    return lastStep!;
  }

  RunResult run({int maxSteps = 10000}) {
    final result = engine.run(state, memory, maxSteps: maxSteps);
    lastStep = result.lastStep;
    return result;
  }

  SimulatorRuntime reset() {
    return SimulatorRuntime.load(project, loader: loader, engine: engine);
  }

  SimulatorSnapshot snapshot({int memoryStart = 0, int memoryLength = 64}) {
    return SimulatorSnapshot(
      machine: state.snapshot(),
      memoryStart: memoryStart,
      memoryBytes: memory.slice(memoryStart, memoryLength),
      lastStep: lastStep,
    );
  }
}
