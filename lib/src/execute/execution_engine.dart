import '../decode/rv64i_decoder.dart';
import '../decode/rv64i_instruction.dart';
import '../errors/sim_error.dart';
import '../memory/memory.dart';
import '../state/cpu_status.dart';
import '../state/machine_state.dart';
import 'execution_result.dart';

class ExecutionEngine {
  const ExecutionEngine({this.decoder = const Rv64iDecoder()});

  static final BigInt _twoTo64 = BigInt.one << 64;
  static final BigInt _signBit64 = BigInt.one << 63;

  final Rv64iDecoder decoder;

  StepResult step(MachineState state, Memory memory) {
    final pcBefore = state.pc;
    try {
      final raw = memory.readUint32LittleEndian(state.pc);
      final instruction = decoder.decode(raw);
      _executeInstruction(state, memory, instruction);
      return StepResult(
        pcBefore: pcBefore,
        pcAfter: state.pc,
        status: state.status,
        instruction: instruction,
      );
    } on SimException catch (error) {
      state.status = CpuStatus.trapped;
      return StepResult(
        pcBefore: pcBefore,
        pcAfter: state.pc,
        status: state.status,
        error: error,
      );
    }
  }

  RunResult run(MachineState state, Memory memory, {int maxSteps = 10000}) {
    state.status = CpuStatus.running;
    StepResult? lastStep;
    var steps = 0;

    while (steps < maxSteps && state.status == CpuStatus.running) {
      lastStep = step(state, memory);
      steps++;
      if (!lastStep.succeeded || lastStep.halted) {
        break;
      }
    }

    return RunResult(
      steps: steps,
      status: state.status,
      stoppedBecauseStepLimit: state.status == CpuStatus.running,
      lastStep: lastStep,
    );
  }

  void _executeInstruction(
    MachineState state,
    Memory memory,
    Rv64iInstruction instruction,
  ) {
    final registers = state.registers;
    final currentPc = state.pc;
    var nextPc = currentPc + 4;

    int x(int index) => registers.read(index);
    int xs(int index) => _signed64(registers.read(index));
    void w(int index, int value) => registers.write(index, value);
    int loadStoreAddress(Rv64iInstruction inst) {
      return _normalizeSigned64(x(inst.rs1) + inst.immediate);
    }

    switch (instruction.op) {
      case Rv64iOp.lui:
        w(instruction.rd, instruction.immediate);
      case Rv64iOp.auipc:
        w(instruction.rd, currentPc + instruction.immediate);
      case Rv64iOp.jal:
        w(instruction.rd, currentPc + 4);
        nextPc = currentPc + instruction.immediate;
      case Rv64iOp.jalr:
        w(instruction.rd, currentPc + 4);
        nextPc = (x(instruction.rs1) + instruction.immediate) & ~1;
      case Rv64iOp.beq:
        if (x(instruction.rs1) == x(instruction.rs2)) {
          nextPc = currentPc + instruction.immediate;
        }
      case Rv64iOp.bne:
        if (x(instruction.rs1) != x(instruction.rs2)) {
          nextPc = currentPc + instruction.immediate;
        }
      case Rv64iOp.blt:
        if (xs(instruction.rs1) < xs(instruction.rs2)) {
          nextPc = currentPc + instruction.immediate;
        }
      case Rv64iOp.bge:
        if (xs(instruction.rs1) >= xs(instruction.rs2)) {
          nextPc = currentPc + instruction.immediate;
        }
      case Rv64iOp.bltu:
        if (_unsignedLessThan(x(instruction.rs1), x(instruction.rs2))) {
          nextPc = currentPc + instruction.immediate;
        }
      case Rv64iOp.bgeu:
        if (!_unsignedLessThan(x(instruction.rs1), x(instruction.rs2))) {
          nextPc = currentPc + instruction.immediate;
        }
      case Rv64iOp.lb:
        w(
          instruction.rd,
          _signExtend(memory.readByte(loadStoreAddress(instruction)), 8),
        );
      case Rv64iOp.lh:
        w(
          instruction.rd,
          _signExtend(
            memory.readUint16LittleEndian(loadStoreAddress(instruction)),
            16,
          ),
        );
      case Rv64iOp.lw:
        w(
          instruction.rd,
          _signExtend(
            memory.readUint32LittleEndian(loadStoreAddress(instruction)),
            32,
          ),
        );
      case Rv64iOp.ld:
        w(
          instruction.rd,
          memory.readUint64LittleEndian(loadStoreAddress(instruction)),
        );
      case Rv64iOp.lbu:
        w(instruction.rd, memory.readByte(loadStoreAddress(instruction)));
      case Rv64iOp.lhu:
        w(
          instruction.rd,
          memory.readUint16LittleEndian(loadStoreAddress(instruction)),
        );
      case Rv64iOp.lwu:
        w(
          instruction.rd,
          memory.readUint32LittleEndian(loadStoreAddress(instruction)),
        );
      case Rv64iOp.sb:
        memory.writeByte(loadStoreAddress(instruction), x(instruction.rs2));
      case Rv64iOp.sh:
        memory.writeUint16LittleEndian(
          loadStoreAddress(instruction),
          x(instruction.rs2),
        );
      case Rv64iOp.sw:
        memory.writeUint32LittleEndian(
          loadStoreAddress(instruction),
          x(instruction.rs2),
        );
      case Rv64iOp.sd:
        memory.writeUint64LittleEndian(
          loadStoreAddress(instruction),
          x(instruction.rs2),
        );
      case Rv64iOp.addi:
        w(instruction.rd, x(instruction.rs1) + instruction.immediate);
      case Rv64iOp.slti:
        w(instruction.rd, xs(instruction.rs1) < instruction.immediate ? 1 : 0);
      case Rv64iOp.sltiu:
        w(
          instruction.rd,
          _unsignedLessThan(x(instruction.rs1), instruction.immediate) ? 1 : 0,
        );
      case Rv64iOp.xori:
        w(instruction.rd, x(instruction.rs1) ^ instruction.immediate);
      case Rv64iOp.ori:
        w(instruction.rd, x(instruction.rs1) | instruction.immediate);
      case Rv64iOp.andi:
        w(instruction.rd, x(instruction.rs1) & instruction.immediate);
      case Rv64iOp.slli:
        w(instruction.rd, x(instruction.rs1) << (instruction.immediate & 0x3f));
      case Rv64iOp.srli:
        w(
          instruction.rd,
          _logicalShiftRight64(
            x(instruction.rs1),
            instruction.immediate & 0x3f,
          ),
        );
      case Rv64iOp.srai:
        w(
          instruction.rd,
          xs(instruction.rs1) >> (instruction.immediate & 0x3f),
        );
      case Rv64iOp.add:
        w(instruction.rd, x(instruction.rs1) + x(instruction.rs2));
      case Rv64iOp.sub:
        w(instruction.rd, x(instruction.rs1) - x(instruction.rs2));
      case Rv64iOp.sll:
        w(instruction.rd, x(instruction.rs1) << (x(instruction.rs2) & 0x3f));
      case Rv64iOp.slt:
        w(instruction.rd, xs(instruction.rs1) < xs(instruction.rs2) ? 1 : 0);
      case Rv64iOp.sltu:
        w(
          instruction.rd,
          _unsignedLessThan(x(instruction.rs1), x(instruction.rs2)) ? 1 : 0,
        );
      case Rv64iOp.xor:
        w(instruction.rd, x(instruction.rs1) ^ x(instruction.rs2));
      case Rv64iOp.srl:
        w(
          instruction.rd,
          _logicalShiftRight64(x(instruction.rs1), x(instruction.rs2) & 0x3f),
        );
      case Rv64iOp.sra:
        w(instruction.rd, xs(instruction.rs1) >> (x(instruction.rs2) & 0x3f));
      case Rv64iOp.or:
        w(instruction.rd, x(instruction.rs1) | x(instruction.rs2));
      case Rv64iOp.and:
        w(instruction.rd, x(instruction.rs1) & x(instruction.rs2));
      case Rv64iOp.addiw:
        w(
          instruction.rd,
          _signExtend(x(instruction.rs1) + instruction.immediate, 32),
        );
      case Rv64iOp.slliw:
        w(
          instruction.rd,
          _signExtend(x(instruction.rs1) << (instruction.immediate & 0x1f), 32),
        );
      case Rv64iOp.srliw:
        w(
          instruction.rd,
          _signExtend(
            (x(instruction.rs1) & 0xffffffff) >> (instruction.immediate & 0x1f),
            32,
          ),
        );
      case Rv64iOp.sraiw:
        w(
          instruction.rd,
          _signExtend(
            _signed32(x(instruction.rs1)) >> (instruction.immediate & 0x1f),
            32,
          ),
        );
      case Rv64iOp.addw:
        w(
          instruction.rd,
          _signExtend(x(instruction.rs1) + x(instruction.rs2), 32),
        );
      case Rv64iOp.subw:
        w(
          instruction.rd,
          _signExtend(x(instruction.rs1) - x(instruction.rs2), 32),
        );
      case Rv64iOp.sllw:
        w(
          instruction.rd,
          _signExtend(x(instruction.rs1) << (x(instruction.rs2) & 0x1f), 32),
        );
      case Rv64iOp.srlw:
        w(
          instruction.rd,
          _signExtend(
            (x(instruction.rs1) & 0xffffffff) >> (x(instruction.rs2) & 0x1f),
            32,
          ),
        );
      case Rv64iOp.sraw:
        w(
          instruction.rd,
          _signExtend(
            _signed32(x(instruction.rs1)) >> (x(instruction.rs2) & 0x1f),
            32,
          ),
        );
      case Rv64iOp.fence:
        break;
      case Rv64iOp.ecall:
        throw SimException(
          SimErrorKind.environmentCall,
          'ECALL is not handled by a phase 1 execution environment.',
          address: currentPc,
        );
      case Rv64iOp.ebreak:
        state.status = CpuStatus.halted;
    }

    if (state.status != CpuStatus.halted) {
      state.status = CpuStatus.running;
      state.pc = _normalizeSigned64(nextPc);
    }
  }

  static int _logicalShiftRight64(int value, int shift) {
    final shifted = _toUnsignedBigInt(value) >> shift;
    return _normalizeSigned64BigInt(shifted);
  }

  static int _signed64(int value) {
    return _normalizeSigned64(value);
  }

  static bool _unsignedLessThan(int left, int right) {
    return _toUnsignedBigInt(left) < _toUnsignedBigInt(right);
  }

  static BigInt _toUnsignedBigInt(int value) {
    var normalized = BigInt.from(value) % _twoTo64;
    if (normalized.isNegative) {
      normalized += _twoTo64;
    }
    return normalized;
  }

  static int _normalizeSigned64(int value) {
    return _normalizeSigned64BigInt(BigInt.from(value));
  }

  static int _normalizeSigned64BigInt(BigInt value) {
    var normalized = value % _twoTo64;
    if (normalized.isNegative) {
      normalized += _twoTo64;
    }
    if (normalized >= _signBit64) {
      normalized -= _twoTo64;
    }
    return normalized.toInt();
  }

  static int _signed32(int value) {
    final normalized = value & 0xffffffff;
    if ((normalized & 0x80000000) == 0) {
      return normalized;
    }
    return normalized - 0x100000000;
  }

  static int _signExtend(int value, int width) {
    final mask = (1 << width) - 1;
    final signBit = 1 << (width - 1);
    final normalized = value & mask;
    return (normalized & signBit) == 0 ? normalized : normalized - (1 << width);
  }
}
