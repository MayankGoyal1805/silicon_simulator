enum Rv64iOp {
  lui,
  auipc,
  jal,
  jalr,
  beq,
  bne,
  blt,
  bge,
  bltu,
  bgeu,
  lb,
  lh,
  lw,
  lbu,
  lhu,
  lwu,
  ld,
  sb,
  sh,
  sw,
  sd,
  addi,
  slti,
  sltiu,
  xori,
  ori,
  andi,
  slli,
  srli,
  srai,
  add,
  sub,
  sll,
  slt,
  sltu,
  xor,
  srl,
  sra,
  or,
  and,
  addiw,
  slliw,
  srliw,
  sraiw,
  addw,
  subw,
  sllw,
  srlw,
  sraw,
  fence,
  ecall,
  ebreak,
}

class Rv64iInstruction {
  const Rv64iInstruction({
    required this.op,
    this.rd = 0,
    this.rs1 = 0,
    this.rs2 = 0,
    this.immediate = 0,
    this.raw = 0,
  });

  final Rv64iOp op;
  final int rd;
  final int rs1;
  final int rs2;
  final int immediate;
  final int raw;
}
