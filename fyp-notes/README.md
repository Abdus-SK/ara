# FYP: Ara (RVV 1.0 vector unit) next to the CVA6 FYP base

Fork: https://github.com/Abdus-SK/ara · Companion repo: https://github.com/Abdus-SK/cva6

This folder is the project journal for Ara. It records the setup, every change made to the
Ara base and why, and how to rebuild and rerun everything. Paste this file into a new chat
to resume work.

## Base version (frozen)

| Item | Value |
|---|---|
| Upstream | https://github.com/pulp-platform/ara |
| Pinned commit | `34bd3bc152421b4601a7bf3d6e8e91ffb545c99e` (2026-08-10, "[chore] update CHANGELOG.md"), latest upstream tag before it: `v3.0` |
| Tag | `fyp-base` |
| Branch | `main` of the fork, no upstream remote (by decision, same as CVA6) |

Rules: never press GitHub's "Sync fork". Compare against the base with
`git diff fyp-base`. Submodule and Bender versions are locked by the pinned commit
(`.gitmodules`, `Bender.lock`).

## Ara's CVA6 is NOT the FYP CVA6

Ara fetches its own CVA6 with Bender into `hardware/deps/cva6`:

| | Ara's CVA6 | FYP CVA6 (Abdus-SK/cva6) |
|---|---|---|
| Source | pulp-platform/cva6, branch `pulp-v2` | openhwgroup/cva6 |
| Commit | `99eac9a6` (2024-09-25, tag `pulp-v2.0.0-alpha.1`) | `81245a47` (2026-09-15) |
| Config | `cv64a6_imafdcv_sv39` (V enabled, accelerator port, `ARIANE_ACCELERATOR_PORT=1`) | `cv64a6_imafdc_sv39` |

So results measured on the FYP CVA6 (hello world, matmul baseline, Vivado V1) do not carry
over to Ara's CVA6. Open decision: keep Ara's CVA6, or port Ara's accelerator interface to the
FYP CVA6.

## Folder layout

| Path | What |
|---|---|
| `~/FYP/fyp/ara` | This repo |
| `~/FYP/fyp/cva6` | FYP CVA6 fork (separate repo) |
| `ara/install/` | Built tools (LLVM, Spike, Verilator), git-ignored |
| `ara/hardware/deps/` | Bender-fetched IPs incl. Ara's CVA6, git-ignored |
| `ara/fyp-notes/` | This journal, env file, helper scripts, evidence logs |

## Pinned tool versions (from the repo)

| Tool | Version | How Ara builds it |
|---|---|---|
| LLVM/Clang (RVV 1.0) | llvm-project `24a30daa` (LLVM 20) | `make toolchain-llvm` (clang+lld, then newlib, then compiler-rt) |
| GCC (optional) | riscv-gnu-toolchain `5842fde8` | `make toolchain-gcc` |
| Spike | riscv-isa-sim `204b88de` (2026-03-24) + `patches/0003-riscv-isa-sim-patch` for the mod build | `make riscv-isa-sim` |
| Verilator | `06263ec7` = v5.046-150 (2026-03-22), built with clang | `make verilator` |
| Bender | 0.31.0 (downloaded) | `make -C hardware checkout` |
| QuestaSim | 2019.3 / 2021.3 | commercial, not available: use the Verilator targets (`verilate`, `simv`) |

Hardware config: `config/default.mk` (lanes, VLEN); also `2_lanes.mk` ... `16_lanes.mk`.

## Expected problems on the laptop (to check, not changed yet)

- `Makefile` lines 152 and 167: Spike is built with `make -j32`; with 7.2 GB RAM this will run out of memory. Use `NUM_JOBS`-style limit.
- `toolchain-llvm-main` builds LLVM with Ninja's default parallelism (all cores); LLVM links need several GB each. Needs `-DLLVM_PARALLEL_LINK_JOBS=1` and a job limit, or a different toolchain (Arch's own clang/lld with the `riscv64-elf-newlib` sysroot) if that compiles Ara's apps.
- `make verilator` uses `CC=clang`: needs Arch's `clang` package.
- Spike and newlib may need the same GCC-16 / CMake-4 workarounds as CVA6 (`-include cstdint`, `CMAKE_POLICY_VERSION_MINIMUM=3.5`).
- `python-requirements.txt`: Arch Python is externally managed (PEP 668), so install into a venv.
- Login shell still exports old `RISCV`, `VERILATOR_ROOT`, `SPIKE_*` values (see CVA6 journal): an `ara-env.sh` must reset them. Run scripts through bash, not fish.

## Changes to the Ara base

| Commit | File | Change | Why |
|---|---|---|---|
| | | | |

## Results

| Date | Test | Result | Log |
|---|---|---|---|
| | | | |

## Journal

- **2026-11-16**: Studied upstream Ara at `34bd3bc1`: submodules, Bender.lock, Makefiles. Found that Ara uses PULP's CVA6 `99eac9a6` (2024), not the FYP CVA6. Forked to Abdus-SK/ara, cloned to `~/FYP/fyp/ara`, reset to `34bd3bc1`, tagged and pushed `fyp-base`. No submodules fetched yet (by decision: `make git-submodules` pulls all of llvm-project). Wrote this journal.

## Next steps

1. Fetch only the needed submodules (Verilator, Spike); `make -C hardware checkout apply-patches` (Bender).
2. Toolchain: try Arch clang + newlib first; build LLVM 20 only if that fails.
3. Verilator (pinned), Spike; fix scripts one commit at a time, logging each here.
4. `hello_world` on Spike, then `make verilate` + `app=hello_world make simv`.
