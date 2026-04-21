import '../errors/sim_error.dart';
import 'rv64i_instruction.dart';

class Rv64iDecoder {
  const Rv64iDecoder();

  Rv64iInstruction decode(int raw) {
    final opcode = raw & 0x7f;
    final rd = _bits(raw, 7, 5);
    final funct3 = _bits(raw, 12, 3);
    final rs1 = _bits(raw, 15, 5);
    final rs2 = _bits(raw, 20, 5);
    final funct7 = _bits(raw, 25, 7);

    switch (opcode) {
      case 0x37:
        return Rv64iInstruction(
          op: Rv64iOp.lui,
          rd: rd,
          immediate: _signed(raw & 0xfffff000, 32),
          raw: raw,
        );
      case 0x17:
        return Rv64iInstruction(
          op: Rv64iOp.auipc,
          rd: rd,
          immediate: _signed(raw & 0xfffff000, 32),
          raw: raw,
        );
      case 0x6f:
        return Rv64iInstruction(
          op: Rv64iOp.jal,
          rd: rd,
          immediate: _jImmediate(raw),
          raw: raw,
        );
      case 0x67:
        if (funct3 != 0) {
          break;
        }
        return Rv64iInstruction(
          op: Rv64iOp.jalr,
          rd: rd,
          rs1: rs1,
          immediate: _iImmediate(raw),
          raw: raw,
        );
      case 0x63:
        return Rv64iInstruction(
          op: _branchOp(funct3),
          rs1: rs1,
          rs2: rs2,
          immediate: _bImmediate(raw),
          raw: raw,
        );
      case 0x03:
        return Rv64iInstruction(
          op: _loadOp(funct3),
          rd: rd,
          rs1: rs1,
          immediate: _iImmediate(raw),
          raw: raw,
        );
      case 0x23:
        return Rv64iInstruction(
          op: _storeOp(funct3),
          rs1: rs1,
          rs2: rs2,
          immediate: _sImmediate(raw),
          raw: raw,
        );
      case 0x13:
        return Rv64iInstruction(
          op: _opImmediate(funct3, funct7),
          rd: rd,
          rs1: rs1,
          immediate: _iImmediate(raw),
          raw: raw,
        );
      case 0x33:
        return Rv64iInstruction(
          op: _opRegister(funct3, funct7),
          rd: rd,
          rs1: rs1,
          rs2: rs2,
          raw: raw,
        );
      case 0x1b:
        return Rv64iInstruction(
          op: _opImmediate32(funct3, funct7),
          rd: rd,
          rs1: rs1,
          immediate: _iImmediate(raw),
          raw: raw,
        );
      case 0x3b:
        return Rv64iInstruction(
          op: _opRegister32(funct3, funct7),
          rd: rd,
          rs1: rs1,
          rs2: rs2,
          raw: raw,
        );
      case 0x0f:
        if (funct3 == 0x0) {
          return Rv64iInstruction(op: Rv64iOp.fence, raw: raw);
        }
        break;
      case 0x73:
        if (raw == 0x00000073) {
          return Rv64iInstruction(op: Rv64iOp.ecall, raw: raw);
        }
        if (raw == 0x00100073) {
          return Rv64iInstruction(op: Rv64iOp.ebreak, raw: raw);
        }
        break;
    }

    throw SimException(
      SimErrorKind.invalidInstruction,
      'Unsupported or invalid RV64I instruction: 0x${raw.toRadixString(16)}.',
    );
  }

  static int _bits(int value, int start, int width) {
    return (value >> start) & ((1 << width) - 1);
  }

  static int _signed(int value, int width) {
    final signBit = 1 << (width - 1);
    final mask = (1 << width) - 1;
    final normalized = value & mask;
    return (normalized & signBit) == 0 ? normalized : normalized - (1 << width);
  }

  static int _iImmediate(int raw) => _signed(raw >> 20, 12);

  static int _sImmediate(int raw) {
    final value = _bits(raw, 7, 5) | (_bits(raw, 25, 7) << 5);
    return _signed(value, 12);
  }

  static int _bImmediate(int raw) {
    final value =
        (_bits(raw, 8, 4) << 1) |
        (_bits(raw, 25, 6) << 5) |
        (_bits(raw, 7, 1) << 11) |
        (_bits(raw, 31, 1) << 12);
    return _signed(value, 13);
  }

  static int _jImmediate(int raw) {
    final value =
        (_bits(raw, 21, 10) << 1) |
        (_bits(raw, 20, 1) << 11) |
        (_bits(raw, 12, 8) << 12) |
        (_bits(raw, 31, 1) << 20);
    return _signed(value, 21);
  }

  static Rv64iOp _branchOp(int funct3) => switch (funct3) {
    0x0 => Rv64iOp.beq,
    0x1 => Rv64iOp.bne,
    0x4 => Rv64iOp.blt,
    0x5 => Rv64iOp.bge,
    0x6 => Rv64iOp.bltu,
    0x7 => Rv64iOp.bgeu,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid branch funct3.',
    ),
  };

  static Rv64iOp _loadOp(int funct3) => switch (funct3) {
    0x0 => Rv64iOp.lb,
    0x1 => Rv64iOp.lh,
    0x2 => Rv64iOp.lw,
    0x3 => Rv64iOp.ld,
    0x4 => Rv64iOp.lbu,
    0x5 => Rv64iOp.lhu,
    0x6 => Rv64iOp.lwu,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid load funct3.',
    ),
  };

  static Rv64iOp _storeOp(int funct3) => switch (funct3) {
    0x0 => Rv64iOp.sb,
    0x1 => Rv64iOp.sh,
    0x2 => Rv64iOp.sw,
    0x3 => Rv64iOp.sd,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid store funct3.',
    ),
  };

  static Rv64iOp _opImmediate(int funct3, int funct7) => switch (funct3) {
    0x0 => Rv64iOp.addi,
    0x2 => Rv64iOp.slti,
    0x3 => Rv64iOp.sltiu,
    0x4 => Rv64iOp.xori,
    0x6 => Rv64iOp.ori,
    0x7 => Rv64iOp.andi,
    0x1 when funct7 == 0x00 => Rv64iOp.slli,
    0x5 when funct7 == 0x00 => Rv64iOp.srli,
    0x5 when funct7 == 0x20 => Rv64iOp.srai,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid immediate arithmetic instruction.',
    ),
  };

  static Rv64iOp _opRegister(int funct3, int funct7) => switch (funct3) {
    0x0 when funct7 == 0x00 => Rv64iOp.add,
    0x0 when funct7 == 0x20 => Rv64iOp.sub,
    0x1 when funct7 == 0x00 => Rv64iOp.sll,
    0x2 when funct7 == 0x00 => Rv64iOp.slt,
    0x3 when funct7 == 0x00 => Rv64iOp.sltu,
    0x4 when funct7 == 0x00 => Rv64iOp.xor,
    0x5 when funct7 == 0x00 => Rv64iOp.srl,
    0x5 when funct7 == 0x20 => Rv64iOp.sra,
    0x6 when funct7 == 0x00 => Rv64iOp.or,
    0x7 when funct7 == 0x00 => Rv64iOp.and,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid register arithmetic instruction.',
    ),
  };

  static Rv64iOp _opImmediate32(int funct3, int funct7) => switch (funct3) {
    0x0 => Rv64iOp.addiw,
    0x1 when funct7 == 0x00 => Rv64iOp.slliw,
    0x5 when funct7 == 0x00 => Rv64iOp.srliw,
    0x5 when funct7 == 0x20 => Rv64iOp.sraiw,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid 32-bit immediate instruction.',
    ),
  };

  static Rv64iOp _opRegister32(int funct3, int funct7) => switch (funct3) {
    0x0 when funct7 == 0x00 => Rv64iOp.addw,
    0x0 when funct7 == 0x20 => Rv64iOp.subw,
    0x1 when funct7 == 0x00 => Rv64iOp.sllw,
    0x5 when funct7 == 0x00 => Rv64iOp.srlw,
    0x5 when funct7 == 0x20 => Rv64iOp.sraw,
    _ => throw const SimException(
      SimErrorKind.invalidInstruction,
      'Invalid 32-bit register instruction.',
    ),
  };
}
