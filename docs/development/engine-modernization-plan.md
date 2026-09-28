# Engine stabilization and modernization plan

Status: **proposal for review; no implementation is authorized by this document**  
Scope: `engine/`, its direct library boundaries, and the Windows build/test path  
Primary constraint: preserve language, stack-file, extension, and external behavior

## 1. Purpose

The engine cannot safely be improved by selecting large files and rewriting them.
Its observable behavior is the product, including undocumented edge cases on which
old stacks may rely. The first goal is therefore to make change *measurable and
reversible*. Architectural cleanup follows only after characterization tests and
repeatable Windows builds provide a safety net.

This plan proposes an incremental route from the current tightly coupled engine to
testable components. It intentionally does not propose a new language, a wholesale
rewrite, a build-system migration, or simultaneous cross-platform modernization.

## 2. Review snapshot

The following observations are from the current tree and are signals, not quality
judgements:

* `engine/src` contains roughly 504,000 lines across C++, headers, and Objective-C++.
  There are more than 500 translation units and 260 headers at the directory root.
  The flat layout obscures ownership and dependency direction.
* `engine/src/globals.h` exposes more than 300 `extern` declarations and includes
  concrete object, UI, stack, media, and platform types. `globals.cpp` is nearly
  1,900 lines. Mutable process-wide state therefore joins otherwise unrelated
  subsystems and makes isolated tests difficult.
* `engine/src/exec.h` is more than 4,400 lines. Execution is also spread across
  `exec.cpp`, `exec-*.cpp`, `exec-interface*.cpp`, commands, functions, expressions,
  dispatch, and object code. File names do not constitute a reliable API boundary.
* Large platform units such as `dskw32.cpp` combine path conversion, sockets,
  processes, files, registry/environment behavior, events, and operating-system
  integration. This makes Windows changes high-blast-radius even when the intended
  change is narrow.
* `engine-sources.gypi` manually inventories source groups and contains repeated
  paths in conditionally assembled lists. GYP targets mix generation, host tools,
  kernel modes, platform selection, resources, and final products.
* There are useful safety-net assets: 322 execution test files, the LiveCode test
  framework, and GoogleTest wiring. However, only a handful of engine C++ tests are
  listed in `engine_test_source_files`, and the Windows CI currently verifies build
  products rather than running behavioral engine tests.
* More than 2,000 `UNCHECKED` annotations exist under `engine/src`. These are useful
  archaeological markers, but they do not distinguish a deliberately infallible
  operation from ignored allocation, conversion, or OS failure.
* Multiple product modes (`development`, `standalone`, `server`, and `installer`),
  host/target tools, LCB modules, generated sources, externals, and platform code are
  linked through one build graph. A refactor can therefore compile in one mode while
  silently breaking another.

These findings point to four root problems: insufficient behavioral baselines,
implicit dependency direction, pervasive ambient state, and a build graph that does
not make architectural boundaries enforceable.

## 3. Non-negotiable compatibility contracts

Before changing implementation, maintainers should approve a written compatibility
matrix. At minimum it must cover:

1. **Language semantics:** parsing, chunk expressions, coercion, number/date/Unicode
   behavior, error text and ordering, message path, and `the result`.
2. **Stack compatibility:** supported stack-file versions, serialization round trips,
   object identifiers, custom properties, scripts, images, and corrupt-input failure.
3. **Embedding and extension surfaces:** legacy external ABI, LCIDL/LCB bindings,
   exported symbols, calling convention, structure layout, and ownership rules.
4. **Product modes:** development IDE, standalone, server, and installer startup,
   shutdown, security restrictions, resource lookup, and command-line behavior.
5. **Windows behavior:** x86-64 only, filesystem/UNC/long paths, registry, process and
   socket behavior, DPI, input, clipboard, accessibility, printing, and supported
   Windows versions.
6. **Persistence and interoperability:** text encodings, line endings, locale/time
   zone behavior, database drivers, network protocols, and generated artifacts.

The default policy should be “preserve unless explicitly deprecated.” A deliberate
behavior change needs a compatibility test, migration note, and separately reviewed
decision record. Tests should normally assert public results, not reproduce private
implementation details.

## 4. Target dependency model

The target is a modular monolith, not microservices. Dependencies should point
inward, with platform details behind narrow interfaces:

```text
products (IDE / standalone / server / installer)
        |
application services (startup, dispatch, persistence, deployment)
        |
language runtime       object model        rendering/media
        \                   |                   /
         domain services and explicit EngineContext
                            |
foundation adapters (strings, values, memory, errors, clocks, filesystem)
                            |
platform adapters (Windows first; macOS/Linux/mobile retained but isolated)
```

Proposed rules:

* Domain code must not include `w32*`, `dsk*`, Cocoa, Android, or Emscripten headers.
* Platform code may implement domain-owned interfaces; domain code may not depend on
  platform implementations.
* Product-mode selection belongs in composition roots, not scattered preprocessor
  branches.
* New mutable globals are forbidden. Existing globals are migrated by capability,
  not copied wholesale into one “god context.”
* Ownership and failure are explicit at each new boundary. Adapters translate old
  conventions at the edge while established public behavior remains unchanged.
* Generated files are build outputs with declared inputs; they are not hand-edited
  source dependencies.

## 5. Work programme

### Phase 0 — Inventory and guardrails

**Objective:** know what ships and stop architectural debt from increasing.

Deliverables:

* Generate a machine-readable inventory mapping every engine source to subsystem,
  owner, platforms, product modes, generated status, and tests. Initially derive it
  from GYP and check it for duplicates/missing paths.
* Record build manifests for all Windows products: file names, PE machine type,
  exports, imports, resources, version fields, and hashes. Hashes diagnose change;
  they are not expected to remain identical.
* Capture public ABI reports for executables, DLLs, and legacy external headers.
* Add lightweight dependency reports (include graph and strongly connected
  components), plus trends for global reads/writes and oversized files.
* Establish decision records under `docs/architecture/decisions/` and assign an owner
  for each approved boundary.
* Add a review rule: cleanup and behavior changes are separate commits/PRs.

Exit criterion: a clean checkout can reproduce the inventory and baseline reports,
and CI identifies unexplained drift.

### Phase 1 — Make the safety net executable

**Objective:** turn existing tests into required evidence before refactoring.

Deliverables:

* Split CI into fast checks, C++ unit tests, headless/server execution tests, Windows
  integration tests, packaging, and release. Packaging must depend on all required
  test jobs rather than merely a successful compile.
* Run the current GoogleTest targets on Windows and publish JUnit-compatible results.
  First fix the harness and determinism; do not “fix” engine behavior while bringing
  the harness online.
* Run the existing execution corpus through a manifest that labels tests as
  headless, desktop, network, timing-sensitive, or quarantined. Quarantine entries
  require an owner, issue, reason, and expiry date.
* Add golden characterization tests for startup/shutdown, dispatch, script errors,
  stack round trips, Unicode/locale, file paths, and external loading.
* Add small Windows smoke tests that launch each produced executable with a bounded
  timeout and assert exit status/log output. GUI tests should use a dedicated runner
  only where a hosted runner cannot exercise the behavior reliably.
* Retain symbols and crash dumps for failing runs; make sanitizer builds a separate,
  initially non-blocking lane where the compiler supports them.

Exit criterion: the same revision produces repeatable test results twice, failures
are attributable, and releases cannot bypass the agreed required suites.

### Phase 2 — Define seams without changing behavior

**Objective:** introduce test points around existing code using branch-by-abstraction.

Start with narrow, high-value capabilities:

1. clock/timers and randomness;
2. environment, locale, and process information;
3. filesystem paths and file handles;
4. sockets and process launching;
5. logging, diagnostics, and error reporting.

For each capability:

* Define the minimal interface in the consumer's subsystem.
* Wrap the current implementation without rewriting it.
* Add a production adapter and a deterministic fake.
* Convert one call path end to end and add characterization tests.
* Measure global access and include coupling before converting the next path.

Avoid a service locator. Pass a small capability or subsystem context to the code
that needs it. An `EngineContext` may aggregate stable subsystem handles at the
composition root, but leaf functions should receive only their actual dependency.

Exit criterion: representative language/runtime tests can run with fake time and I/O,
and no platform headers leak through the new interfaces.

### Phase 3 — Decompose Windows platform code

**Objective:** improve the supported platform first while retaining compatibility.

Extract cohesive adapters from `dskw32.cpp`, `w32dc.cpp`, `w32event.cpp`, printer,
theme, and related units in this suggested order:

1. path normalization and Win32/NT path conversion;
2. file and directory operations;
3. process, environment, registry, and shell operations;
4. Winsock initialization, sockets, and wake-up integration;
5. event/input/clipboard services;
6. windows, display/DPI/theme, graphics, and printing.

Each extraction should keep a forwarding compatibility layer, add table-driven tests
for boundary cases, and have one reason to revert. Win32 handles should acquire small
RAII owners at the adapter boundary; internal callers should not learn new raw-handle
ownership conventions. UTF-16 conversion must be centralized and tested with empty,
invalid, long, UNC, device, and non-BMP paths.

Exit criterion: filesystem, process, and socket code can be built/tested independently
of the UI, and the legacy entry points are thin forwarders.

### Phase 4 — Partition runtime state

**Objective:** replace ambient mutable state with lifecycle-owned state.

Do not migrate all globals at once. Classify every declaration in `globals.h` as:

* immutable configuration/constants;
* process service;
* engine-instance state;
* execution-context state;
* UI/session state;
* cached/derived state;
* obsolete or duplicate.

Move one coherent cluster at a time, beginning with low-fan-out state. Give each
cluster explicit initialization, shutdown, invariants, and thread-affinity rules.
During migration, legacy names may forward to the owned state so callers can move
incrementally. Add assertions for lifecycle violations rather than relying on static
initialization order.

Exit criterion: startup/shutdown and one headless execution path operate through
owned contexts; the count of writable global declarations decreases monotonically.

### Phase 5 — Separate language execution from host effects

**Objective:** make the interpreter understandable and testable without changing the
language.

* Document the pipeline: tokenization/parsing, syntax objects, evaluation, dispatch,
  value conversion, error propagation, and host calls.
* Split `exec.h` by stable concepts, while preserving facade headers until consumers
  migrate. Do not begin by mechanically splitting `exec.cpp`.
* Define an explicit execution context containing current object/handler, locals,
  result, error sink, security capabilities, cancellation, and host services.
* Normalize new code on one result/error convention. Adapt legacy `Exec_stat`,
  boolean/out-parameter, and global-error patterns at boundaries instead of performing
  a repository-wide signature rewrite.
* Use differential tests: run old and refactored paths against the execution corpus
  and compare value, result, errors, messages, and serialized state.

Exit criterion: selected pure language features run without desktop initialization,
and dependency reports show language code no longer importing UI/platform layers.

### Phase 6 — Object model, rendering, and remaining products

Only after the earlier seams are proven:

* Separate object identity/lifetime, persistence, properties, script attachment,
  layout, and painting currently interwoven across object/control classes.
* Introduce rendering command/data boundaries before replacing graphics internals.
* Move deployment and product-specific startup behind application services.
* Apply proven Windows adapter patterns to retained platforms. Do not claim support
  for an untested platform merely because it compiles.

This phase should be planned as multiple programmes, not one refactor PR.

### Phase 7 — Build-system evolution

Do this last enough that architecture is known, but not after GYP becomes impossible
to run. First make GYP describe the new libraries and enforce boundaries. Then prove a
second generator against the same source manifest, generated inputs, compile flags,
product matrix, tests, and artifact reports. Migrate target by target. Remove GYP only
after two release candidates have equivalent supported outputs.

A CMake migration, if selected in a separate decision, is a delivery mechanism—not
an architectural cleanup—and must not be bundled with semantic changes.

## 6. Proposed component boundaries

| Component | Owns | Must not own |
| --- | --- | --- |
| Foundation | values, strings, memory helpers, diagnostics primitives | engine globals, UI, OS policy |
| Language | lexer/parser, syntax, evaluation semantics | windows, files, sockets, rendering |
| Runtime | execution context, dispatch, scheduling, security capabilities | concrete Win32/Cocoa calls |
| Object model | identity, hierarchy, properties, persistence contracts | native window/event loops |
| Rendering | render data/commands, surfaces, text/image contracts | object serialization, script dispatch |
| Host services | filesystem, clock, process, network interfaces | language semantics |
| Windows adapters | Win32 implementations and handle ownership | cross-platform policy |
| Products | composition and lifecycle for IDE/server/standalone/installer | reusable subsystem internals |

Cycles between these components are defects to remove or explicitly document as
temporary exceptions with an owner and target date.

## 7. CI and release gates

Recommended progression:

| Gate | Pull request | Main/nightly | Release tag |
| --- | --- | --- | --- |
| source/build manifest validation | required | required | required |
| Windows release compile | required | required | required |
| C++ unit tests | required | required | required |
| headless execution tests | required, shardable | full corpus | full corpus |
| Windows integration smoke tests | focused | full | full |
| ABI/export comparison | report, then required | required | required |
| stack round-trip corpus | focused | full | full |
| static analysis/sanitizers | changed code, advisory first | full advisory | reviewed |
| package/PE/checksum validation | optional | required | required |
| signing/provenance | no | optional | required once configured |

Warnings must not become an unactionable backlog. Introduce new compiler/static-analysis
warnings per component, baseline existing findings, forbid regressions, and burn down
the baseline deliberately.

## 8. Change protocol

Every extraction PR should include:

1. the compatibility contract and issue it protects;
2. characterization tests added before structural edits;
3. the old and new dependency path;
4. supported product/platform configurations exercised;
5. ABI/artifact comparison results;
6. failure and rollback plan;
7. metrics affected (globals, cycles, includes, test coverage, build time);
8. no unrelated formatting or mass rename.

Prefer small vertical slices over horizontal churn. A useful slice moves one behavior
through an interface, adapter, fake, tests, and production composition. Header-only
facades, forwarding functions, and temporary duplication are acceptable when they
make rollback safe; unbounded compatibility layers are not.

## 9. What not to do

* Do not rewrite the interpreter or object model from scratch.
* Do not replace GYP, compilers, third-party libraries, error handling, and runtime
  architecture in one change.
* Do not convert every pointer to a smart pointer mechanically; ownership must first
  be documented at a boundary.
* Do not hide all globals behind a singleton or service locator.
* Do not split files based only on size; split by responsibility and dependency.
* Do not reformat entire legacy files while changing behavior.
* Do not delete odd behavior until the compatibility owner decides whether it is a
  bug, a relied-upon quirk, or an obsolete path.
* Do not make flaky or failing tests silently optional. Quarantine is explicit debt.

## 10. First three proposed milestones

### Milestone A — Baseline (2–4 weeks)

Deliver only inventories, test harness fixes, reports, and decision records. Run the
existing C++ and headless execution tests in Windows CI. No engine behavior changes.

### Milestone B — First seam (2–4 weeks)

Extract clock/timer and diagnostic capabilities behind interfaces, with fakes and
characterization tests. This validates the context/adaptor technique on relatively
small state before touching filesystem or dispatch semantics.

### Milestone C — Windows filesystem slice (4–8 weeks)

Extract path conversion and filesystem operations from the Windows disk layer. Cover
drive-relative, UNC, NT/device, long, Unicode, missing, denied, symlink/reparse, and
read-only cases. Preserve the old entry points as forwarders and compare behavior
against the baseline corpus.

Dates are estimates for sequencing, not commitments. Milestones should be stopped or
replanned if characterization reveals undocumented compatibility requirements.

## 11. Decisions required before implementation

Maintainers should decide and record:

1. Which Windows versions and filesystems are supported?
2. Which stack-file versions and external ABIs are immutable contracts?
3. Which product modes must remain releasable throughout modernization?
4. Is multiple engine-instance support a goal, or is explicit single-instance state
   sufficient?
5. Which tests block pull requests, nightly builds, and releases?
6. What is the policy for discovered legacy quirks and security defects?
7. Which compiler/toolchain upgrade is desired, and only after which baseline gates?
8. Who owns each proposed component and approves boundary exceptions?

No structural implementation should start until questions 1–5 have named owners and
documented answers. That turns “detangling” from an open-ended rewrite into a series
of compatibility-preserving, reviewable changes.

## Appendix A — Reproducing the review metrics

These commands are intentionally simple so the snapshot can be repeated without a
new analysis tool:

```sh
find engine/src -type f \( -name '*.cpp' -o -name '*.h' -o -name '*.mm' \) \
  -print0 | xargs -0 cat | wc -l
find engine/src -maxdepth 1 -type f -name '*.h' | wc -l
rg '^extern ' engine/src/globals.h | wc -l
rg -o 'UNCHECKED' engine/src --glob '*.{cpp,h,mm}' | wc -l
find engine/exec-tests -type f -name '*.test' | wc -l
find engine/src -type f \( -name '*.cpp' -o -name '*.h' -o -name '*.mm' \) \
  -printf '%s %p\n' | sort -nr | head
```

Line counts are directional indicators only. The modernization programme should be
judged by compatibility, dependency direction, testability, operational reliability,
and ease of safe change—not by reducing line counts.
