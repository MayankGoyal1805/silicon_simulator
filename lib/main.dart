import 'dart:io';

import 'package:flutter/material.dart';

import 'silicon_simulator.dart';

void main() {
  runApp(const SiliconSimulatorApp());
}

class SiliconSimulatorApp extends StatelessWidget {
  const SiliconSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xff10231f);
    const copper = Color(0xffc06b36);
    const paper = Color(0xfff4efe6);

    return MaterialApp(
      title: 'Silicon Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: copper,
          brightness: Brightness.light,
          surface: paper,
        ),
        scaffoldBackgroundColor: paper,
        useMaterial3: true,
        textTheme: Typography.blackMountainView.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
      ),
      home: const SimulatorWorkbench(),
    );
  }
}

class SimulatorWorkbench extends StatefulWidget {
  const SimulatorWorkbench({super.key});

  @override
  State<SimulatorWorkbench> createState() => _SimulatorWorkbenchState();
}

class _SimulatorWorkbenchState extends State<SimulatorWorkbench>
    with SingleTickerProviderStateMixin {
  static const _defaultAssembly = '''
addi t0, zero, 5
addi t1, zero, 7
add  t2, t0, t1
sd   t2, 64(zero)
ebreak
''';

  late final TabController _tabController;
  late final TextEditingController _assemblyController;
  late final TextEditingController _memorySizeController;
  late final TextEditingController _loadAddressController;
  late final TextEditingController _entryPointController;
  late final TextEditingController _registerOverridesController;
  late final TextEditingController _memoryInitController;
  late final TextEditingController _projectPathController;
  late final TextEditingController _memoryWindowStartController;
  late final TextEditingController _memoryWindowLengthController;

  SimulatorRuntime? _runtime;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _assemblyController = TextEditingController(text: _defaultAssembly);
    _memorySizeController = TextEditingController(text: '65536');
    _loadAddressController = TextEditingController(text: '0');
    _entryPointController = TextEditingController(text: '0');
    _registerOverridesController = TextEditingController(text: 'sp=128');
    _memoryInitController = TextEditingController(text: '64: 00 00 00 00');
    _projectPathController = TextEditingController(
      text: 'docs/sample_project.json',
    );
    _memoryWindowStartController = TextEditingController(text: '0');
    _memoryWindowLengthController = TextEditingController(text: '128');
    _loadProject();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assemblyController.dispose();
    _memorySizeController.dispose();
    _loadAddressController.dispose();
    _entryPointController.dispose();
    _registerOverridesController.dispose();
    _memoryInitController.dispose();
    _projectPathController.dispose();
    _memoryWindowStartController.dispose();
    _memoryWindowLengthController.dispose();
    super.dispose();
  }

  void _loadProject() {
    _perform(() {
      final project = _buildProjectFromControls();
      _runtime = SimulatorRuntime.load(project);
      _message = 'Project loaded.';
    });
  }

  void _step() {
    _perform(() {
      final result = _runtimeOrThrow().step();
      _message = _describeStep(result);
    });
  }

  void _run() {
    _perform(() {
      final result = _runtimeOrThrow().run(maxSteps: 1000);
      _message = result.stoppedBecauseStepLimit
          ? 'Stopped after ${result.steps} steps.'
          : 'Run finished after ${result.steps} steps.';
    });
  }

  void _reset() {
    _perform(() {
      final runtime = _runtimeOrThrow();
      _runtime = runtime.reset();
      _message = 'Runtime reset.';
    });
  }

  void _saveProjectFile() {
    _perform(() {
      final project = _buildProjectFromControls();
      final path = _projectPathController.text.trim();
      if (path.isEmpty) {
        throw const SimException(
          SimErrorKind.invalidProject,
          'Enter a project file path before saving.',
        );
      }
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(project.toJsonString());
      _message = 'Saved project to $path';
    });
  }

  void _openProjectFile() {
    _perform(() {
      final path = _projectPathController.text.trim();
      if (path.isEmpty) {
        throw const SimException(
          SimErrorKind.invalidProject,
          'Enter a project file path before opening.',
        );
      }
      final file = File(path);
      if (!file.existsSync()) {
        throw SimException(
          SimErrorKind.invalidProject,
          'Project file does not exist: $path',
        );
      }
      final project = SimulationProject.fromJsonString(file.readAsStringSync());
      _applyProjectToControls(project);
      _runtime = SimulatorRuntime.load(project);
      _message = 'Opened project from $path';
    });
  }

  void _perform(VoidCallback action) {
    setState(() {
      try {
        action();
      } on SimException catch (error) {
        _message = error.message;
      } on Object catch (error) {
        _message = error.toString();
      }
    });
  }

  SimulatorRuntime _runtimeOrThrow() {
    final runtime = _runtime;
    if (runtime == null) {
      throw const SimException(
        SimErrorKind.invalidProject,
        'Load a project before executing.',
      );
    }
    return runtime;
  }

  SimulationProject _buildProjectFromControls() {
    return SimulationProject(
      memorySizeBytes: _parseIntField(
        _memorySizeController.text,
        fieldName: 'Memory size',
      ),
      loadAddress: _parseIntField(
        _loadAddressController.text,
        fieldName: 'Load address',
      ),
      entryPoint: _parseIntField(
        _entryPointController.text,
        fieldName: 'Entry point',
      ),
      assemblySource: _assemblyController.text,
      registerOverrides: _parseRegisterOverrides(
        _registerOverridesController.text,
      ),
      memoryInitBlocks: _parseMemoryInitBlocks(_memoryInitController.text),
    );
  }

  void _applyProjectToControls(SimulationProject project) {
    _assemblyController.text = project.assemblySource;
    _memorySizeController.text = project.memorySizeBytes.toString();
    _loadAddressController.text = project.loadAddress.toString();
    _entryPointController.text = project.entryPoint.toString();
    _registerOverridesController.text = _formatRegisterOverrides(
      project.registerOverrides,
    );
    _memoryInitController.text = _formatMemoryInitBlocks(
      project.memoryInitBlocks,
    );
  }

  int _parseIntField(String raw, {required String fieldName}) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw SimException(
        SimErrorKind.invalidProject,
        '$fieldName cannot be empty.',
      );
    }
    if (text.startsWith('0x')) {
      return int.parse(text.substring(2), radix: 16);
    }
    if (text.startsWith('-0x')) {
      return -int.parse(text.substring(3), radix: 16);
    }
    return int.parse(text);
  }

  Map<String, int> _parseRegisterOverrides(String content) {
    final overrides = <String, int>{};
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final parts = line.split('=');
      if (parts.length != 2) {
        throw SimException(
          SimErrorKind.invalidProject,
          'Register override must use name=value syntax.',
        );
      }
      final name = parts.first.trim();
      registerIndex(name);
      overrides[name] = _parseIntField(parts.last, fieldName: 'Register value');
    }
    return overrides;
  }

  List<MemoryInitBlock> _parseMemoryInitBlocks(String content) {
    final blocks = <MemoryInitBlock>[];
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final parts = line.split(':');
      if (parts.length != 2) {
        throw SimException(
          SimErrorKind.invalidProject,
          'Memory initialization must use address: bytes syntax.',
        );
      }
      final address = _parseIntField(parts.first, fieldName: 'Memory address');
      final byteTokens = parts.last
          .trim()
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
      final bytes = byteTokens
          .map((token) => int.parse(token, radix: 16))
          .toList(growable: false);
      blocks.add(MemoryInitBlock(address: address, bytes: bytes));
    }
    return blocks;
  }

  String _formatRegisterOverrides(Map<String, int> overrides) {
    if (overrides.isEmpty) {
      return '';
    }
    return overrides.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('\n');
  }

  String _formatMemoryInitBlocks(List<MemoryInitBlock> blocks) {
    if (blocks.isEmpty) {
      return '';
    }
    return blocks
        .map(
          (block) =>
              '${block.address}: '
              '${block.bytes.map(_byteHex).join(' ')}',
        )
        .join('\n');
  }

  String _describeStep(StepResult result) {
    if (result.trapped) {
      return result.error?.message ?? 'Execution trapped.';
    }
    if (result.halted) {
      return 'Execution halted by ebreak.';
    }
    return 'Executed ${result.instruction?.op.name ?? 'instruction'}.';
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    final memoryStart = int.tryParse(_memoryWindowStartController.text) ?? 0;
    final memoryLength =
        int.tryParse(_memoryWindowLengthController.text) ?? 128;
    final snapshot = runtime?.snapshot(
      memoryStart: memoryStart,
      memoryLength: memoryLength,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xfff4efe6), Color(0xffe6d7bd)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(snapshot: snapshot),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 1100;
                      final controls = _ControlsPanel(
                        tabController: _tabController,
                        assemblyController: _assemblyController,
                        memorySizeController: _memorySizeController,
                        loadAddressController: _loadAddressController,
                        entryPointController: _entryPointController,
                        registerOverridesController:
                            _registerOverridesController,
                        memoryInitController: _memoryInitController,
                        projectPathController: _projectPathController,
                        onOpen: _openProjectFile,
                        onSave: _saveProjectFile,
                        onLoad: _loadProject,
                        onStep: _step,
                        onRun: _run,
                        onReset: _reset,
                        message: _message,
                      );
                      final state = _StatePanel(
                        snapshot: snapshot,
                        memoryWindowStartController:
                            _memoryWindowStartController,
                        memoryWindowLengthController:
                            _memoryWindowLengthController,
                        onRefresh: () => setState(() {}),
                      );

                      if (narrow) {
                        return ListView(
                          children: [
                            SizedBox(height: 760, child: controls),
                            const SizedBox(height: 16),
                            SizedBox(height: 760, child: state),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: controls),
                          const SizedBox(width: 16),
                          Expanded(flex: 7, child: state),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final SimulatorSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final status = snapshot?.machine.status.name ?? 'not loaded';
    final pc = snapshot == null ? '----' : _hex(snapshot!.machine.pc, width: 4);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silicon Simulator',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Phase 1 RV64I backend + Phase 1.5 workbench'),
              ],
            ),
          ),
          _Metric(label: 'PC', value: pc),
          const SizedBox(width: 12),
          _Metric(label: 'Status', value: status),
        ],
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.tabController,
    required this.assemblyController,
    required this.memorySizeController,
    required this.loadAddressController,
    required this.entryPointController,
    required this.registerOverridesController,
    required this.memoryInitController,
    required this.projectPathController,
    required this.onOpen,
    required this.onSave,
    required this.onLoad,
    required this.onStep,
    required this.onRun,
    required this.onReset,
    required this.message,
  });

  final TabController tabController;
  final TextEditingController assemblyController;
  final TextEditingController memorySizeController;
  final TextEditingController loadAddressController;
  final TextEditingController entryPointController;
  final TextEditingController registerOverridesController;
  final TextEditingController memoryInitController;
  final TextEditingController projectPathController;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onStep;
  final VoidCallback onRun;
  final VoidCallback onReset;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Project Controls',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: projectPathController,
                  decoration: const InputDecoration(
                    labelText: 'Project file path',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonal(onPressed: onOpen, child: const Text('Open')),
              FilledButton.tonal(onPressed: onSave, child: const Text('Save')),
              FilledButton(onPressed: onLoad, child: const Text('Load')),
              FilledButton.tonal(onPressed: onStep, child: const Text('Step')),
              FilledButton.tonal(onPressed: onRun, child: const Text('Run')),
              OutlinedButton(onPressed: onReset, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: tabController,
            tabs: const [
              Tab(text: 'Assembly'),
              Tab(text: 'Machine Setup'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _AssemblyEditor(controller: assemblyController),
                _SetupPanel(
                  memorySizeController: memorySizeController,
                  loadAddressController: loadAddressController,
                  entryPointController: entryPointController,
                  registerOverridesController: registerOverridesController,
                  memoryInitController: memoryInitController,
                ),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _AssemblyEditor extends StatelessWidget {
  const _AssemblyEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      expands: true,
      maxLines: null,
      minLines: null,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 15,
        height: 1.4,
        color: Color(0xfffff7e8),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xff172723),
        hintText: 'Write RV64I assembly here...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      cursorColor: const Color(0xfff4c17b),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.memorySizeController,
    required this.loadAddressController,
    required this.entryPointController,
    required this.registerOverridesController,
    required this.memoryInitController,
  });

  final TextEditingController memorySizeController;
  final TextEditingController loadAddressController;
  final TextEditingController entryPointController;
  final TextEditingController registerOverridesController;
  final TextEditingController memoryInitController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: memorySizeController,
                decoration: const InputDecoration(
                  labelText: 'Memory size (bytes)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: loadAddressController,
                decoration: const InputDecoration(
                  labelText: 'Load address',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: entryPointController,
                decoration: const InputDecoration(
                  labelText: 'Entry point',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Register overrides',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: registerOverridesController,
          minLines: 5,
          maxLines: 7,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'sp=128\na0=5',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Memory initialization blocks',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: memoryInitController,
          minLines: 5,
          maxLines: 8,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: '64: 2a 00 00 00',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.snapshot,
    required this.memoryWindowStartController,
    required this.memoryWindowLengthController,
    required this.onRefresh,
  });

  final SimulatorSnapshot? snapshot;
  final TextEditingController memoryWindowStartController;
  final TextEditingController memoryWindowLengthController;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return Container(
        decoration: _panelDecoration(),
        child: const Center(child: Text('Load a project to inspect state.')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Machine State',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: memoryWindowStartController,
                  decoration: const InputDecoration(
                    labelText: 'Mem start',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: memoryWindowLengthController,
                  decoration: const InputDecoration(
                    labelText: 'Mem bytes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onRefresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LastStepBanner(lastStep: snapshot!.lastStep),
          const SizedBox(height: 12),
          Expanded(
            flex: 3,
            child: _RegisterGrid(registers: snapshot!.machine.registers),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: _MemoryGrid(
              start: snapshot!.memoryStart,
              bytes: snapshot!.memoryBytes,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastStepBanner extends StatelessWidget {
  const _LastStepBanner({required this.lastStep});

  final StepResult? lastStep;

  @override
  Widget build(BuildContext context) {
    final step = lastStep;
    if (step == null) {
      return const SizedBox.shrink();
    }

    final text = step.error != null
        ? 'Last step trapped: ${step.error!.message}'
        : 'Last step: ${step.instruction?.op.name ?? 'unknown'} '
              '(${_hex(step.pcBefore, width: 4)} -> ${_hex(step.pcAfter, width: 4)})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text),
    );
  }
}

class _RegisterGrid extends StatelessWidget {
  const _RegisterGrid({required this.registers});

  final List<int> registers;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: registers.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisExtent: 48,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  'x$index',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Text(
                  _hex(registers[index]),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemoryGrid extends StatelessWidget {
  const _MemoryGrid({required this.start, required this.bytes});

  final int start;
  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var offset = 0; offset < bytes.length; offset += 8) {
      final rowBytes = bytes.skip(offset).take(8).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  _hex(start + offset, width: 4),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rowBytes.map((byte) => _byteHex(byte)).join('  '),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(children: rows),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: const Color(0xfffffbf2).withValues(alpha: 0.84),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: const Color(0xffd8c5a3)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x2210231f),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ],
  );
}

String _hex(int value, {int width = 16}) {
  final prefix = value < 0 ? '-0x' : '0x';
  final magnitude = value.abs().toRadixString(16).padLeft(width, '0');
  return '$prefix$magnitude';
}

String _byteHex(int value) => value.toRadixString(16).padLeft(2, '0');
