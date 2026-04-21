import '../errors/sim_error.dart';
import '../state/register_names.dart';

class AssemblyProgram {
  const AssemblyProgram(this.bytes);

  final List<int> bytes;
}

class Assembler {
  const Assembler();

  AssemblyProgram assemble(String source, {int baseAddress = 0}) {
    final lines = _parseLines(source);
    final labels = <String, int>{};
    var pc = baseAddress;

    for (final line in lines) {
      if (line.label != null) {
        labels[line.label!] = pc;
      }
      if (line.instruction != null) {
        pc += 4;
      }
    }

    final bytes = <int>[];
    pc = baseAddress;
    for (final line in lines) {
      final instruction = line.instruction;
      if (instruction == null) {
        continue;
      }
      final word = _encodeInstruction(instruction, pc, labels);
      for (var i = 0; i < 4; i++) {
        bytes.add((word >> (8 * i)) & 0xff);
      }
      pc += 4;
    }

    return AssemblyProgram(List<int>.unmodifiable(bytes));
  }

  List<_AssemblyLine> _parseLines(String source) {
    final lines = <_AssemblyLine>[];
    for (final rawLine in source.split('\n')) {
      var line = rawLine.split('#').first.split('//').first.trim();
      if (line.isEmpty) {
        continue;
      }

      String? label;
      if (line.contains(':')) {
        final parts = line.split(':');
        label = parts.first.trim();
        if (label.isEmpty) {
          throw const SimException(SimErrorKind.assembly, 'Empty label.');
        }
        line = parts.sublist(1).join(':').trim();
      }

      lines.add(
        _AssemblyLine(label: label, instruction: line.isEmpty ? null : line),
      );
    }
    return lines;
  }

  int _encodeInstruction(String instruction, int pc, Map<String, int> labels) {
    final parts = instruction.trim().split(RegExp(r'\s+', multiLine: true));
    final mnemonic = parts.first.toLowerCase();
    final operands = _splitOperands(
      instruction.substring(parts.first.length).trim(),
    );

    if (mnemonic == 'nop') {
      return _iType(0, 0, 0x0, 0, 0x13);
    }
    if (mnemonic == 'mv') {
      _expectCount(mnemonic, operands, 2);
      return _iType(0, _reg(operands[1]), 0x0, _reg(operands[0]), 0x13);
    }
    if (mnemonic == 'li') {
      _expectCount(mnemonic, operands, 2);
      final immediate = _imm(operands[1], labels, pc);
      _checkSignedImmediate(mnemonic, immediate, 12);
      return _iType(immediate, 0, 0x0, _reg(operands[0]), 0x13);
    }
    if (mnemonic == 'ebreak') {
      _expectCount(mnemonic, operands, 0);
      return 0x00100073;
    }
    if (mnemonic == 'ecall') {
      _expectCount(mnemonic, operands, 0);
      return 0x00000073;
    }
    if (mnemonic == 'fence') {
      _expectCount(mnemonic, operands, 0);
      return 0x0000000f;
    }

    if (_rTypeOps.containsKey(mnemonic)) {
      _expectCount(mnemonic, operands, 3);
      final spec = _rTypeOps[mnemonic]!;
      return _rType(
        spec.funct7,
        _reg(operands[2]),
        _reg(operands[1]),
        spec.funct3,
        _reg(operands[0]),
        spec.opcode,
      );
    }

    if (_iTypeOps.containsKey(mnemonic)) {
      _expectCount(mnemonic, operands, 3);
      final spec = _iTypeOps[mnemonic]!;
      final immediate = _imm(operands[2], labels, pc);
      _checkSignedImmediate(mnemonic, immediate, 12);
      final encodedImm = spec.shift
          ? immediate | (spec.funct7 << 5)
          : immediate;
      return _iType(
        encodedImm,
        _reg(operands[1]),
        spec.funct3,
        _reg(operands[0]),
        spec.opcode,
      );
    }

    if (_loadOps.containsKey(mnemonic)) {
      _expectCount(mnemonic, operands, 2);
      final spec = _loadOps[mnemonic]!;
      final address = _parseAddress(operands[1], labels, pc);
      _checkSignedImmediate(mnemonic, address.offset, 12);
      return _iType(
        address.offset,
        address.baseRegister,
        spec.funct3,
        _reg(operands[0]),
        0x03,
      );
    }

    if (_storeOps.containsKey(mnemonic)) {
      _expectCount(mnemonic, operands, 2);
      final spec = _storeOps[mnemonic]!;
      final address = _parseAddress(operands[1], labels, pc);
      _checkSignedImmediate(mnemonic, address.offset, 12);
      return _sType(
        address.offset,
        _reg(operands[0]),
        address.baseRegister,
        spec.funct3,
        0x23,
      );
    }

    if (_branchOps.containsKey(mnemonic)) {
      _expectCount(mnemonic, operands, 3);
      final spec = _branchOps[mnemonic]!;
      final target = _imm(operands[2], labels, pc);
      final offset = labels.containsKey(operands[2]) ? target - pc : target;
      _checkSignedImmediate(mnemonic, offset, 13);
      return _bType(
        offset,
        _reg(operands[1]),
        _reg(operands[0]),
        spec.funct3,
        0x63,
      );
    }

    if (mnemonic == 'jal') {
      if (operands.length == 1) {
        final target = _imm(operands[0], labels, pc);
        return _jType(
          labels.containsKey(operands[0]) ? target - pc : target,
          1,
          0x6f,
        );
      }
      _expectCount(mnemonic, operands, 2);
      final target = _imm(operands[1], labels, pc);
      return _jType(
        labels.containsKey(operands[1]) ? target - pc : target,
        _reg(operands[0]),
        0x6f,
      );
    }

    if (mnemonic == 'jalr') {
      _expectCount(mnemonic, operands, 2);
      final address = _parseAddress(operands[1], labels, pc);
      return _iType(
        address.offset,
        address.baseRegister,
        0,
        _reg(operands[0]),
        0x67,
      );
    }

    if (mnemonic == 'lui' || mnemonic == 'auipc') {
      _expectCount(mnemonic, operands, 2);
      final immediate = _imm(operands[1], labels, pc);
      return _uType(
        immediate,
        _reg(operands[0]),
        mnemonic == 'lui' ? 0x37 : 0x17,
      );
    }

    throw SimException(
      SimErrorKind.assembly,
      'Unsupported assembly mnemonic: $mnemonic.',
    );
  }

  List<String> _splitOperands(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }
    return text.split(',').map((operand) => operand.trim()).toList();
  }

  _Address _parseAddress(String text, Map<String, int> labels, int pc) {
    final match = RegExp(r'^(.+)\((.+)\)$').firstMatch(text.trim());
    if (match == null) {
      throw SimException(
        SimErrorKind.assembly,
        'Invalid memory operand: $text.',
      );
    }
    return _Address(
      offset: _imm(match.group(1)!.trim(), labels, pc),
      baseRegister: _reg(match.group(2)!.trim()),
    );
  }

  int _reg(String name) => registerIndex(name);

  int _imm(String token, Map<String, int> labels, int pc) {
    final trimmed = token.trim();
    final labelValue = labels[trimmed];
    if (labelValue != null) {
      return labelValue;
    }
    return int.tryParse(trimmed) ??
        (trimmed.startsWith('0x')
            ? int.tryParse(trimmed.substring(2), radix: 16)
            : null) ??
        (trimmed.startsWith('-0x')
            ? -int.parse(trimmed.substring(3), radix: 16)
            : throw SimException(
                SimErrorKind.assembly,
                'Invalid immediate or label: $token at pc $pc.',
              ));
  }

  void _expectCount(String mnemonic, List<String> operands, int count) {
    if (operands.length != count) {
      throw SimException(
        SimErrorKind.assembly,
        '$mnemonic expects $count operands, got ${operands.length}.',
      );
    }
  }

  void _checkSignedImmediate(String mnemonic, int value, int bits) {
    final min = -(1 << (bits - 1));
    final max = (1 << (bits - 1)) - 1;
    if (value < min || value > max) {
      throw SimException(
        SimErrorKind.assembly,
        '$mnemonic immediate $value does not fit in $bits signed bits.',
      );
    }
  }

  int _rType(int funct7, int rs2, int rs1, int funct3, int rd, int opcode) {
    return (funct7 << 25) |
        (rs2 << 20) |
        (rs1 << 15) |
        (funct3 << 12) |
        (rd << 7) |
        opcode;
  }

  int _iType(int imm, int rs1, int funct3, int rd, int opcode) {
    return ((imm & 0xfff) << 20) |
        (rs1 << 15) |
        (funct3 << 12) |
        (rd << 7) |
        opcode;
  }

  int _sType(int imm, int rs2, int rs1, int funct3, int opcode) {
    final value = imm & 0xfff;
    return (((value >> 5) & 0x7f) << 25) |
        (rs2 << 20) |
        (rs1 << 15) |
        (funct3 << 12) |
        ((value & 0x1f) << 7) |
        opcode;
  }

  int _bType(int imm, int rs2, int rs1, int funct3, int opcode) {
    final value = imm & 0x1fff;
    return (((value >> 12) & 0x1) << 31) |
        (((value >> 5) & 0x3f) << 25) |
        (rs2 << 20) |
        (rs1 << 15) |
        (funct3 << 12) |
        (((value >> 1) & 0xf) << 8) |
        (((value >> 11) & 0x1) << 7) |
        opcode;
  }

  int _uType(int imm, int rd, int opcode) {
    return (imm & 0xfffff000) | (rd << 7) | opcode;
  }

  int _jType(int imm, int rd, int opcode) {
    final value = imm & 0x1fffff;
    return (((value >> 20) & 0x1) << 31) |
        (((value >> 1) & 0x3ff) << 21) |
        (((value >> 11) & 0x1) << 20) |
        (((value >> 12) & 0xff) << 12) |
        (rd << 7) |
        opcode;
  }
}

class _AssemblyLine {
  const _AssemblyLine({this.label, this.instruction});

  final String? label;
  final String? instruction;
}

class _Address {
  const _Address({required this.offset, required this.baseRegister});

  final int offset;
  final int baseRegister;
}

class _InstructionSpec {
  const _InstructionSpec({
    required this.opcode,
    required this.funct3,
    this.funct7 = 0,
    this.shift = false,
  });

  final int opcode;
  final int funct3;
  final int funct7;
  final bool shift;
}

const _rTypeOps = <String, _InstructionSpec>{
  'add': _InstructionSpec(opcode: 0x33, funct3: 0x0),
  'sub': _InstructionSpec(opcode: 0x33, funct3: 0x0, funct7: 0x20),
  'sll': _InstructionSpec(opcode: 0x33, funct3: 0x1),
  'slt': _InstructionSpec(opcode: 0x33, funct3: 0x2),
  'sltu': _InstructionSpec(opcode: 0x33, funct3: 0x3),
  'xor': _InstructionSpec(opcode: 0x33, funct3: 0x4),
  'srl': _InstructionSpec(opcode: 0x33, funct3: 0x5),
  'sra': _InstructionSpec(opcode: 0x33, funct3: 0x5, funct7: 0x20),
  'or': _InstructionSpec(opcode: 0x33, funct3: 0x6),
  'and': _InstructionSpec(opcode: 0x33, funct3: 0x7),
  'addw': _InstructionSpec(opcode: 0x3b, funct3: 0x0),
  'subw': _InstructionSpec(opcode: 0x3b, funct3: 0x0, funct7: 0x20),
  'sllw': _InstructionSpec(opcode: 0x3b, funct3: 0x1),
  'srlw': _InstructionSpec(opcode: 0x3b, funct3: 0x5),
  'sraw': _InstructionSpec(opcode: 0x3b, funct3: 0x5, funct7: 0x20),
};

const _iTypeOps = <String, _InstructionSpec>{
  'addi': _InstructionSpec(opcode: 0x13, funct3: 0x0),
  'slti': _InstructionSpec(opcode: 0x13, funct3: 0x2),
  'sltiu': _InstructionSpec(opcode: 0x13, funct3: 0x3),
  'xori': _InstructionSpec(opcode: 0x13, funct3: 0x4),
  'ori': _InstructionSpec(opcode: 0x13, funct3: 0x6),
  'andi': _InstructionSpec(opcode: 0x13, funct3: 0x7),
  'slli': _InstructionSpec(opcode: 0x13, funct3: 0x1, shift: true),
  'srli': _InstructionSpec(opcode: 0x13, funct3: 0x5, shift: true),
  'srai': _InstructionSpec(
    opcode: 0x13,
    funct3: 0x5,
    funct7: 0x20,
    shift: true,
  ),
  'addiw': _InstructionSpec(opcode: 0x1b, funct3: 0x0),
  'slliw': _InstructionSpec(opcode: 0x1b, funct3: 0x1, shift: true),
  'srliw': _InstructionSpec(opcode: 0x1b, funct3: 0x5, shift: true),
  'sraiw': _InstructionSpec(
    opcode: 0x1b,
    funct3: 0x5,
    funct7: 0x20,
    shift: true,
  ),
};

const _loadOps = <String, _InstructionSpec>{
  'lb': _InstructionSpec(opcode: 0x03, funct3: 0x0),
  'lh': _InstructionSpec(opcode: 0x03, funct3: 0x1),
  'lw': _InstructionSpec(opcode: 0x03, funct3: 0x2),
  'ld': _InstructionSpec(opcode: 0x03, funct3: 0x3),
  'lbu': _InstructionSpec(opcode: 0x03, funct3: 0x4),
  'lhu': _InstructionSpec(opcode: 0x03, funct3: 0x5),
  'lwu': _InstructionSpec(opcode: 0x03, funct3: 0x6),
};

const _storeOps = <String, _InstructionSpec>{
  'sb': _InstructionSpec(opcode: 0x23, funct3: 0x0),
  'sh': _InstructionSpec(opcode: 0x23, funct3: 0x1),
  'sw': _InstructionSpec(opcode: 0x23, funct3: 0x2),
  'sd': _InstructionSpec(opcode: 0x23, funct3: 0x3),
};

const _branchOps = <String, _InstructionSpec>{
  'beq': _InstructionSpec(opcode: 0x63, funct3: 0x0),
  'bne': _InstructionSpec(opcode: 0x63, funct3: 0x1),
  'blt': _InstructionSpec(opcode: 0x63, funct3: 0x4),
  'bge': _InstructionSpec(opcode: 0x63, funct3: 0x5),
  'bltu': _InstructionSpec(opcode: 0x63, funct3: 0x6),
  'bgeu': _InstructionSpec(opcode: 0x63, funct3: 0x7),
};
