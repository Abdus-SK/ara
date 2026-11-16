# Ara FYP environment. Use inside bash, from the ara folder: source fyp-notes/ara-env.sh
# Works like cva6-env.sh in the CVA6 fork: every tool path is set here, nothing is taken
# from the login shell (VERILATOR_ROOT, RISCV and the Spike variables are overwritten or cleared), and nothing is built into ara/install/.
export ARA_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")"
# The FYP CVA6 fork, cloned next to this repo (Bender uses it as ../cva6).
export CVA6_ROOT="$(readlink -f "${FYP_CVA6:-$ARA_ROOT/../cva6}")"

# Old values from the login shell (see the CVA6 journal) must not leak in.
unset SPIKE_SRC_DIR SPIKE_INSTALL_DIR RISCV   # VERILATOR_ROOT is set below

# Verilator: the same pinned 5.008 as the CVA6 results (built by CVA6's install-verilator.sh).
# Ara pins 5.046; 5.008 understands every option Ara's verilate target uses.
# Use 5.008's build tree (kit layout), not its "make install" copy: Ara builds with
# --hierarchical, and 5.008 then relaunches itself with VERILATOR_ROOT=<prefix>/share/verilator,
# where an installed 5.008 has no verilator_bin (it is only in <prefix>/bin). In the build tree
# bin/verilator_bin and include/ sit under one root, so the relaunch works.
# Same binary as the installed one (install only copies bin/verilator_bin).
export VERILATOR_ROOT="$CVA6_ROOT/tools/verilator-v5.008/build-v5.008"
export veril_path="$VERILATOR_ROOT/bin"
export PATH="$VERILATOR_ROOT/bin:$PATH"
[ -x "$VERILATOR_ROOT/bin/verilator_bin" ] || echo "ara-env.sh: no $VERILATOR_ROOT/bin/verilator_bin" >&2

# Default hardware/software configuration (both Makefiles read ARA_CONFIGURATION).
export ARA_CONFIGURATION="${ARA_CONFIGURATION:-2_lanes}"

# Apps: Arch's clang/lld (packages clang, lld, llvm) instead of Ara's own LLVM 20 build,
# with the newlib and libgcc of Arch's riscv64-elf-gcc (rv64imafdc/lp64d multilib).
FYP_NEWLIB_LIB=/usr/riscv64-elf/lib/rv64imafdc/lp64d
FYP_LIBGCC_DIR="$(dirname "$(riscv64-elf-gcc -march=rv64imafdc -mabi=lp64d -print-libgcc-file-name)")"
export RISCV_PREFIX=/usr/bin/
export LLVM_FLAGS="--target=riscv64-unknown-elf --sysroot=/usr/riscv64-elf -rtlib=libgcc -L$FYP_NEWLIB_LIB -L$FYP_LIBGCC_DIR -march=rv64gcv_zfh_zvfh -mabi=lp64d -mno-relax -fuse-ld=lld"
# riscv-tests are compiled with GCC (Ara's riscv-tests flow); same libraries.
# -Dsptbr=satp: Ara's riscv-tests copy still writes the CSR by its pre-2017 name (sptbr,
# renamed satp in privileged spec 1.10); binutils of GCC 16 no longer knows the old name.
# Same CSR number (0x180), so the tests are unchanged. The .S files go through cpp.
export RISCV_CC_GCC="riscv64-elf-gcc -L$FYP_NEWLIB_LIB -L$FYP_LIBGCC_DIR -Dsptbr=satp"
