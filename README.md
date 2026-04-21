# Silicon Simulator

Silicon Simulator is a RISC-V-first CPU simulator for Computer System Architecture learning and experimentation.

The current implementation focus is Phase 1: a deterministic backend for the `RV64I` base integer architecture. The UI will be built after the backend contract is stable.

## Current Backend Scope

- Simulation project model
- JSON project serialization/deserialization
- Assembly-driven program input
- Register file with the RISC-V `x0` invariant
- Machine state with program counter and execution status
- Byte-addressable memory
- Little-endian memory helpers
- Program loader
- RV64I instruction decoder
- Single-step and run execution engine
- Structured step/run results
- UI-facing simulator runtime facade
- Initial assembler for Phase 1 assembly workflows
- Backend tests

## Current UI Scope

The first Flutter workbench is implemented with:

- assembly editor
- machine setup tab
- memory size, load address, and entry point configuration
- register override configuration
- memory initialization block configuration
- project file open/save by path
- load, step, run, and reset controls
- program counter and CPU status display
- last-step banner
- register grid
- memory inspector
- execution/error message display

## Commands

```bash
flutter analyze
flutter test
```

## Documentation

- Overview docs: `docs/markd/overview/`
- Guided implementation chunks: `docs/markd/chunks/`
- Slides: `docs/slides2.md`
- Report: `docs/report.tex`

## Product Direction

Phase 1 is a RISC-V-first simulator, not a general custom CPU builder. The backend is kept modular enough for future expansion, but the immediate goal is a useful and testable `RV64I` simulator.
