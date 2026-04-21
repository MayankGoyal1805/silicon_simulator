import 'cpu_status.dart';
import 'register_file.dart';

class MachineStateSnapshot {
  const MachineStateSnapshot({
    required this.pc,
    required this.status,
    required this.registers,
  });

  final int pc;
  final CpuStatus status;
  final List<int> registers;
}

class MachineState {
  MachineState({
    required this.pc,
    required this.registers,
    this.status = CpuStatus.ready,
  });

  int pc;
  final RegisterFile registers;
  CpuStatus status;

  MachineStateSnapshot snapshot() {
    return MachineStateSnapshot(
      pc: pc,
      status: status,
      registers: registers.snapshot(),
    );
  }
}
