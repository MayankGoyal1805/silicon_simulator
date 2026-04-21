import 'dart:convert';

import '../errors/sim_error.dart';

const phase1Isa = 'rv64i';
const defaultMemorySizeBytes = 65536;

class MemoryInitBlock {
  const MemoryInitBlock({required this.address, required this.bytes});

  final int address;
  final List<int> bytes;

  Map<String, Object> toJson() {
    return <String, Object>{'address': address, 'bytes': bytes};
  }

  factory MemoryInitBlock.fromJson(Map<String, Object?> json) {
    final bytes = (json['bytes'] as List<Object?>? ?? const <Object?>[])
        .map((byte) => byte as int)
        .toList(growable: false);
    return MemoryInitBlock(address: json['address'] as int? ?? 0, bytes: bytes);
  }
}

class SimulationProject {
  const SimulationProject({
    this.isa = phase1Isa,
    this.memorySizeBytes = defaultMemorySizeBytes,
    this.loadAddress = 0,
    this.entryPoint = 0,
    this.assemblySource = '',
    this.registerOverrides = const <String, int>{},
    this.memoryInitBlocks = const <MemoryInitBlock>[],
  });

  final String isa;
  final int memorySizeBytes;
  final int loadAddress;
  final int entryPoint;
  final String assemblySource;
  final Map<String, int> registerOverrides;
  final List<MemoryInitBlock> memoryInitBlocks;

  SimulationProject copyWith({
    String? isa,
    int? memorySizeBytes,
    int? loadAddress,
    int? entryPoint,
    String? assemblySource,
    Map<String, int>? registerOverrides,
    List<MemoryInitBlock>? memoryInitBlocks,
  }) {
    return SimulationProject(
      isa: isa ?? this.isa,
      memorySizeBytes: memorySizeBytes ?? this.memorySizeBytes,
      loadAddress: loadAddress ?? this.loadAddress,
      entryPoint: entryPoint ?? this.entryPoint,
      assemblySource: assemblySource ?? this.assemblySource,
      registerOverrides: registerOverrides ?? this.registerOverrides,
      memoryInitBlocks: memoryInitBlocks ?? this.memoryInitBlocks,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'isa': isa,
      'memorySizeBytes': memorySizeBytes,
      'loadAddress': loadAddress,
      'entryPoint': entryPoint,
      'assemblySource': assemblySource,
      'registerOverrides': registerOverrides,
      'memoryInitBlocks': memoryInitBlocks
          .map((block) => block.toJson())
          .toList(growable: false),
    };
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory SimulationProject.fromJson(Map<String, Object?> json) {
    final rawOverrides =
        json['registerOverrides'] as Map<Object?, Object?>? ??
        const <Object?, Object?>{};
    final overrides = <String, int>{};
    for (final entry in rawOverrides.entries) {
      overrides[entry.key.toString()] = entry.value as int;
    }

    final rawBlocks =
        json['memoryInitBlocks'] as List<Object?>? ?? const <Object?>[];

    return SimulationProject(
      isa: json['isa'] as String? ?? phase1Isa,
      memorySizeBytes:
          json['memorySizeBytes'] as int? ?? defaultMemorySizeBytes,
      loadAddress: json['loadAddress'] as int? ?? 0,
      entryPoint: json['entryPoint'] as int? ?? 0,
      assemblySource: json['assemblySource'] as String? ?? '',
      registerOverrides: overrides,
      memoryInitBlocks: rawBlocks
          .map(
            (block) => MemoryInitBlock.fromJson(block as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }

  factory SimulationProject.fromJsonString(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) {
      throw const SimException(
        SimErrorKind.invalidProject,
        'Project file must contain a JSON object.',
      );
    }
    return SimulationProject.fromJson(decoded);
  }

  List<String> validate() {
    final errors = <String>[];

    if (isa.toLowerCase() != phase1Isa) {
      errors.add('Phase 1 only supports rv64i.');
    }

    if (memorySizeBytes <= 0) {
      errors.add('Memory size must be positive.');
    }

    if (loadAddress < 0) {
      errors.add('Load address cannot be negative.');
    }

    if (entryPoint < 0) {
      errors.add('Entry point cannot be negative.');
    }

    if (memorySizeBytes > 0 && loadAddress >= memorySizeBytes) {
      errors.add('Load address must be inside memory.');
    }

    if (memorySizeBytes > 0 && entryPoint >= memorySizeBytes) {
      errors.add('Entry point must be inside memory.');
    }

    for (final block in memoryInitBlocks) {
      if (block.address < 0) {
        errors.add('Memory init block address cannot be negative.');
      }
      if (block.bytes.any((byte) => byte < 0 || byte > 0xff)) {
        errors.add('Memory init block bytes must be in the range 0..255.');
      }
      if (block.address + block.bytes.length > memorySizeBytes) {
        errors.add('Memory init block extends beyond memory.');
      }
    }

    return errors;
  }

  void validateOrThrow() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw SimException(SimErrorKind.invalidProject, errors.join(' '));
    }
  }
}
