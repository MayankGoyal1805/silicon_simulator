enum SimErrorKind {
  invalidProject,
  assembly,
  invalidInstruction,
  unsupportedInstruction,
  memoryAccess,
  misalignedAccess,
  environmentCall,
}

class SimException implements Exception {
  const SimException(this.kind, this.message, {this.address});

  final SimErrorKind kind;
  final String message;
  final int? address;

  @override
  String toString() {
    final location = address == null
        ? ''
        : ' at 0x${address!.toRadixString(16)}';
    return 'SimException($kind$location): $message';
  }
}
