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

## Tools actually used (decided 2026-11-16/17)

Nothing is built into `ara/install/`; `fyp-notes/ara-env.sh` sets every path.

| Tool | Used | Ara pins | Why |
|---|---|---|---|
| Verilator | **5.008** from `../cva6/tools/verilator-v5.008/build-v5.008` (its build tree) | 5.046 | Same simulator as the CVA6 results. Ara ran on 5.012 from Aug 2023 to Mar 2026; 5.008 has every option the `verilate` target uses (`--hierarchical`, `-Wno-ENUMVALUE`, ...). If 5.008 hits a Verilator bug, build 5.046 and note it here. |
| C compiler (apps) | Arch **clang 23.1.4** + **lld 23** (`clang lld llvm` packages) | LLVM 20 from source | Saves the LLVM build. Cycle counts can differ from Ara's published numbers with another compiler version. |
| C library | Arch `riscv64-elf-newlib` + libgcc of `riscv64-elf-gcc` 16.2.0, multilib `rv64imafdc/lp64d` | newlib + compiler-rt from source | Clang flags: `--target=riscv64-unknown-elf --sysroot=/usr/riscv64-elf -rtlib=libgcc` + `-L` to both library folders |
| GCC (riscv-tests) | Arch `riscv64-elf-gcc` 16.2.0 | riscv-gnu-toolchain from source | Same libraries |
| Python (data generators) | Arch `python-numpy` | `python-requirements.txt` | System package, no venv |
| Spike | not used yet | `204b88de` + patch | Not needed for the Verilator smoke tests |

Verilator 5.008 build tree instead of its installed copy: with `--hierarchical` (used by Ara, not
by CVA6), 5.008 relaunches itself for each hierarchical block with
`VERILATOR_ROOT=<prefix>/share/verilator`, where the installed 5.008 has no `verilator_bin`
(`make install` puts it only in `<prefix>/bin`). First `verilate` run failed after 2 s with
`share/verilator/verilator_bin: No such file or directory` (2026-11-17 01:36). The build tree has
`bin/verilator_bin` and `include/` under one root, so `ara-env.sh` sets
`VERILATOR_ROOT=.../build-v5.008`. Same binary: the install step only copies it.

Arch's package list was out of date on 2026-11-16 (pacman 404s); fixed with `sudo pacman -Syu`.

## Expected problems on the laptop (to check, not changed yet)

Most of these no longer apply because nothing is built from source (see above); kept for reference.

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

Run with `bash fyp-notes/run-smoke.sh [apps|verilate|simv|rvtests|all] [config]` (default
`all 2_lanes`), from bash. Logs with tool versions go to `fyp-notes/logs/`.

From Ara's CI (`.github/workflows/ci.yml`), smallest config `2_lanes` (VLEN 2048):

1. `make -C apps bin/hello_world` (and `imatmul`, `fmatmul`): compile apps with the RVV toolchain.
2. `config=2_lanes make -C hardware verilate`: build the Verilator model.
3. `config=2_lanes app=hello_world make -C hardware simv`, then `imatmul`, `fmatmul`.
4. `config=2_lanes make -C apps riscv_tests` and `config=2_lanes make -C hardware riscv_tests_simv`: the vector ISA tests.
5. Optional: `make -C apps riscv_tests_spike` (needs Spike).

CI runs 17 apps x 4 configs; the three apps above cover the integer and floating-point paths.

## Problems met

| Date | Step | Problem | Cause | Fix |
|---|---|---|---|---|
| 2026-11-17 | verilate | `share/verilator/verilator_bin: No such file or directory`, exit 2 after 2 s | 5.008 installed layout + `--hierarchical` (see Tools) | `VERILATOR_ROOT` = 5.008 build tree |
| 2026-11-17 | rvtests | `rv64si/dirty.S:25: Error: unknown CSR 'sptbr'`; make stopped, so `rv64si-dirty` onwards and all ~170 vector tests (`rv64uv`) were never built (89 scalar tests ran, all passed) | Ara's riscv-tests copy uses `sptbr`, the pre-1.10 name of `satp`; GCC 16's binutils dropped it | `-Dsptbr=satp` in `RISCV_CC_GCC` (same CSR 0x180); `run-smoke.sh` builds with `make -k` |
| 2026-11-17 | rvtests, run 2 | 271/271 passed (177/177 vector) but `build exit=2`: `rv64si-ara-ma_fetch` not built (1 of Ara's 272 tests) | `ma_fetch.S:187` reads `sbadaddr`, pre-1.10 name of `stval` (and `mbadaddr` = `mtval`) | `-Dsbadaddr=stval -Dmbadaddr=mtval` |

Warning seen and accepted: `PINMISSING vmfpu.sv:1093 ... 'early_valid_o'`: the openhwgroup cvfpu
has an extra output that Ara's VMFPU leaves unconnected (output only, no effect).

## Results

| Date | Step | Result | Log |
|---|---|---|---|
| 2026-11-17 | apps (2_lanes) | hello_world, imatmul, fmatmul built, exit 0 | `logs/build-*-2_lanes.log` |
| 2026-11-17 | verilate (2_lanes) | Ara + FYP CVA6 model built, exit 0, 2 min 15 s (C++ compiled by g++: 5.008 ignores `--compiler clang` for the compiler choice) | `logs/verilate-2_lanes.log` |
| 2026-11-17 | simv hello_world | "Ariane says Hello!", SUCCESS (tohost 0), 1,188 cycles | `logs/simv-hello_world-2_lanes.log` |
| 2026-11-17 | simv imatmul (int64) | 128x128x128: 1,069,263 cycles, 3.92 OP/cycle, 98.1 % of 4 OP/cycle; result Passed; run 1,596,028 cycles, 7 min 40 s | `logs/simv-imatmul-2_lanes.log` |
| 2026-11-17 | simv fmatmul (fp64) | 128x128x128: 1,064,284 cycles, 3.94 FLOP/cycle, 98.5 %; result Passed; run 1,733,870 cycles, 8 min 14 s | `logs/simv-fmatmul-2_lanes.log` |
| 2026-11-17 | riscv-tests, run 1 | 89/89 scalar tests passed (rv64ui, um, uc, uf, ud, si-csr); build stopped at `rv64si-dirty`, vector tests not built | (log overwritten by run 2) |
| 2026-11-17 | riscv-tests, run 2 | 271/271 passed, incl. 177/177 vector (rv64uv); `rv64si-ara-ma_fetch` not built (`sbadaddr`) | (log overwritten by run 3) |
| 2026-11-17 | **riscv-tests, run 3 (final)** | **272/272 passed, build exit 0**: 177/177 vector (rv64uv) + 95 scalar (rv64ui 51, um 13, uc 1, uf 11, ud 12, si 7 incl. ma_fetch); 23 min | `logs/riscv-tests-2_lanes.log` |

**Smoke-test status (2_lanes): all passed.** Ara + FYP CVA6 builds and runs Ara's CI set: hello_world,
imatmul, fmatmul and all 272 riscv-tests Ara defines (Ara's own list in `apps/common/riscv_tests.mk`;
rv64ua atomics are not in it).

Matmul cycles per size (app timer), 2 lanes:

| n | imatmul | util. | fmatmul | util. |
|---|---|---|---|---|
| 4 | 666 | 4.8 % | 516 | 6.2 % |
| 8 | 966 | 26.5 % | 833 | 30.7 % |
| 16 | 3,185 | 64.3 % | 3,230 | 63.4 % |
| 32 | 18,336 | 89.4 % | 18,309 | 89.5 % |
| 64 | 136,372 | 96.1 % | 139,246 | 94.1 % |
| 128 | 1,069,263 | 98.1 % | 1,064,284 | 98.5 % |

fmatmul passing is the check for the VMFPU change (openhwgroup cvfpu).

## Journal

- **2026-11-17**: riscv-tests run 3: 272/272 passed (177/177 vector), build exit 0. Smoke set complete on 2_lanes. Logs committed (`.gitignore` ignores `*log`, so `fyp-notes/logs/` is un-ignored).
- **2026-11-17**: verilate passed (2 min 15 s); hello_world, imatmul, fmatmul passed on Ara + FYP CVA6 (98 % utilisation at 128x128). riscv-tests: 89/89 scalar passed, build stopped on `sptbr`; fixed with `-Dsptbr=satp` and `make -k`. Run 2: 271/271 passed incl. all 177 vector tests; only `ma_fetch` not built (`sbadaddr`), fixed with `-Dsbadaddr=stval -Dmbadaddr=mtval`.
- **2026-11-17**: Smoke step `apps` passed on 2_lanes (clang 23.1.5 after `pacman -Syu`; CVA6 at `caea7968`). First `verilate` failed in 2 s: 5.008's installed layout breaks `--hierarchical`; switched `VERILATOR_ROOT` to 5.008's build tree.
- **2026-11-17**: Tools decided: CVA6's Verilator 5.008, Arch clang/lld 23 with Arch newlib + libgcc (installed `lld`, `python-numpy`; `pacman -Syu` needed first). First test: `hello_world` (default 4-lane config) compiled and linked with clang 23 (9.9 KB, vector instructions in the dump). Added `ara-env.sh` and `run-smoke.sh`.
- **2026-11-16**: Decided to use the FYP CVA6 fork instead of PULP's CVA6. Switched Bender to `../cva6` with version overrides, removed the CLIC ports, adapted VMFPU to the openhwgroup cvfpu. Elaboration check with slang: no new errors versus upstream. Smoke-test list taken from Ara's CI.
- **2026-11-16**: Studied upstream Ara at `34bd3bc1`: submodules, Bender.lock, Makefiles. Found that Ara uses PULP's CVA6 `99eac9a6` (2024), not the FYP CVA6. Forked to Abdus-SK/ara, cloned to `~/FYP/fyp/ara`, reset to `34bd3bc1`, tagged and pushed `fyp-base`. No submodules fetched yet (by decision: `make git-submodules` pulls all of llvm-project). Wrote this journal.

## Next steps

1. Optional: same smoke set on `4_lanes` (default config) to check the swap at another size.
2. Optional: build Ara's pinned Verilator 5.046 and rerun, to rule out 5.008 effects before quoting numbers.
3. Fair scalar-vs-vector comparison: the same matmul (size, data type, -O level) on CVA6 alone and on Ara.
