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

## CVA6: the FYP fork, not Ara's own (decided 2026-11-16)

Upstream Ara fetches its own CVA6 with Bender into `hardware/deps/cva6`:

| | Ara's CVA6 | FYP CVA6 (Abdus-SK/cva6) |
|---|---|---|
| Source | pulp-platform/cva6, branch `pulp-v2` | openhwgroup/cva6 |
| Commit | `99eac9a6` (2024-09-25, tag `pulp-v2.0.0-alpha.1`) | `81245a47` (2026-09-15) |
| Config | `cv64a6_imafdcv_sv39` (V enabled, accelerator port, `ARIANE_ACCELERATOR_PORT=1`) | `cv64a6_imafdc_sv39` |

**Decision:** Ara uses the FYP CVA6 fork, cloned next to this repo (`../cva6`), as a Bender path
dependency. Same CVA6 RTL as the CVA6 results (hello world, matmul baseline, Vivado V1), only with
the `cv64a6_imafdcv_sv39` config (V on) instead of `cv64a6_imafdc_sv39`.

What had to change (commits below): Bender manifest and version pins, CLIC ports (PULP-only),
and the VMFPU FPU settings, because the FYP CVA6 brings openhwgroup cvfpu `3eb6afe` (5 FP formats,
4 op groups) instead of PULP's cvfpu (6 formats with FP8ALT, DOTP group). The accelerator interface
itself (`cvxif_req_t`/`resp_t`, `accelerator_req_t`, `acc_mmu_req_t`, `acc_dispatcher.sv`) matched
without changes.

Check (2026-11-16, Claude's workspace, slang 12.1 elaborating `ara_tb_verilator`, 2 lanes,
VLEN 2048, Verilator targets and defines): Ara + FYP CVA6 gives 3 errors, upstream Ara + PULP CVA6
gives the same 3 plus 2 more. All five are slang being stricter than Verilator (enum `default: '0`
in `lane_sequencer.sv`; dead `DATA_USER_EN` branch in `wt_dcache_wbuffer.sv`), so the swap adds no
new errors. Not yet built with Verilator.

The laptop's `~/FYP/fyp/cva6` must have its submodules filled in (`core/cvfpu`,
`core/cvfpu/src/fpu_div_sqrt_mvp`, `core/cache_subsystem/hpdcache`).

## Folder layout

| Path | What |
|---|---|
| `~/FYP/fyp/ara` | This repo |
| `~/FYP/fyp/cva6` | FYP CVA6 fork (separate repo) |
| `ara/install/` | Built tools (LLVM, Spike, Verilator), git-ignored |
| `ara/hardware/deps/` | Bender-fetched IPs (axi, common_cells, fpnew, ...), git-ignored; CVA6 is NOT here, it is `../cva6` |
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

Upstream file paths. All three are needed before Ara compiles.

| Commit | File | Change | Why |
|---|---|---|---|
| `Use the FYP CVA6 fork` | `Bender.yml` line 13, line 77 | `cva6` from git `pulp-v2` to `{ path: "../cva6" }`; `mock_uart.sv` read from `../cva6/...` | Use the FYP CVA6; a path dependency is not copied into `hardware/deps` |
| same | `Bender.local` (new), `.gitignore`, `Bender.lock` | Overrides pin axi `853ede23`, common_cells `c27bce39`, tech_cells_generic `7968dd6e`, common_verification `9c07fa86` (the fyp-base lock) | FYP CVA6 asks for axi ^0.31 vs Ara's ^0.39 (Bender conflict); pins keep Ara's tested IP versions |
| `Remove CLIC ports` | `hardware/src/ara_system.sv` lines 148-155 | 8 `.clic_*` connections removed | PULP-only CVA6 ports |
| `Adapt VMFPU` | `hardware/src/lane/vmfpu.sv` lines 851, 858-868, 1098 | FP8ALT format, DOTP op group and `hart_id_i` removed | openhwgroup cvfpu has 5 formats, 4 op groups, no `hart_id_i` |
| same | `hardware/src/ara_soc.sv` line 621 | FP8ALT check no longer reads `CVA6Cfg.XF8ALT` | Field absent in the FYP CVA6 config |

## Smoke tests (Ara's equivalent of the CVA6 hello-world check)

From Ara's CI (`.github/workflows/ci.yml`), smallest config `2_lanes` (VLEN 2048):

1. `make -C apps bin/hello_world` (and `imatmul`, `fmatmul`): compile apps with the RVV toolchain.
2. `config=2_lanes make -C hardware verilate`: build the Verilator model.
3. `config=2_lanes app=hello_world make -C hardware simv`, then `imatmul`, `fmatmul`.
4. `config=2_lanes make -C apps riscv_tests` and `config=2_lanes make -C hardware riscv_tests_simv`: the vector ISA tests.
5. Optional: `make -C apps riscv_tests_spike` (needs Spike).

CI runs 17 apps x 4 configs; the three apps above cover the integer and floating-point paths.

## Results

| Date | Test | Result | Log |
|---|---|---|---|
| | | | |

## Journal

- **2026-11-16**: Decided to use the FYP CVA6 fork instead of PULP's CVA6. Switched Bender to `../cva6` with version overrides, removed the CLIC ports, adapted VMFPU to the openhwgroup cvfpu. Elaboration check with slang: no new errors versus upstream. Smoke-test list taken from Ara's CI.
- **2026-11-16**: Studied upstream Ara at `34bd3bc1`: submodules, Bender.lock, Makefiles. Found that Ara uses PULP's CVA6 `99eac9a6` (2024), not the FYP CVA6. Forked to Abdus-SK/ara, cloned to `~/FYP/fyp/ara`, reset to `34bd3bc1`, tagged and pushed `fyp-base`. No submodules fetched yet (by decision: `make git-submodules` pulls all of llvm-project). Wrote this journal.

## Next steps

1. Fetch only the needed submodules (Verilator, Spike); `make -C hardware checkout apply-patches` (Bender; CVA6 comes from `../cva6`).
2. Toolchain: try Arch clang + newlib first; build LLVM 20 only if that fails.
3. Verilator (pinned), Spike; fix scripts one commit at a time, logging each here.
4. `hello_world` on Spike, then `make verilate` + `app=hello_world make simv`.
