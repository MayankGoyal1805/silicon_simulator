import '../decode/rv64i_instruction.dart';
import '../errors/sim_error.dart';
import '../state/cpu_status.dart';

class StepResult {
  const StepResult({
    required this.pcBefore,
    required this.pcAfter,
    required this.status,
    this.instruction,
    this.error,
  });

  final int pcBefore;
  final int pcAfter;
  final CpuStatus status;
  final Rv64iInstruction? instruction;
  final SimException? error;

  bool get succeeded => error == null;
  bool get halted => status == CpuStatus.halted;
  bool get trapped => status == CpuStatus.trapped;
}

class RunResult {
  const RunResult({
    required this.steps,
    required this.status,
    required this.stoppedBecauseStepLimit,
    required this.lastStep,
  });

  final int steps;
  final CpuStatus status;
  final bool stoppedBecauseStepLimit;
  final StepResult? lastStep;

  bool get halted => status == CpuStatus.halted;
  bool get trapped => status == CpuStatus.trapped;
}
