# Ara FYP environment. Use inside bash, from the ara folder: source fyp-notes/ara-env.sh
# Works like cva6-env.sh in the CVA6 fork: every tool path is set here, nothing is taken
# from the login shell, and nothing is built into ara/install/.
export ARA_ROOT="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")"
# The FYP CVA6 fork, cloned next to this repo (Bender uses it as ../cva6).
export CVA6_ROOT="$(readlink -f "${FYP_CVA6:-$ARA_ROOT/../cva6}")"

# Old values from the login shell (see the CVA6 journal) must not leak in.
unset VERILATOR_ROOT SPIKE_SRC_DIR SPIKE_INSTALL_DIR RISCV

# Verilator: the same pinned 5.008 as the CVA6 results (built by CVA6's install-verilator.sh).
# Ara pins 5.046; 5.008 understands every option Ara's verilate target uses.
export VERILATOR_INSTALL_DIR="$CVA6_ROOT/tools/verilator-v5.008"
export veril_path="$VERILATOR_INSTALL_DIR/bin"
export PATH="$VERILATOR_INSTALL_DIR/bin:$PATH"

# Default hardware/software configuration (both Makefiles read ARA_CONFIGURATION).
export ARA_CONFIGURATION="${ARA_CONFIGURATION:-2_lanes}"

# Apps: Arch's clang/lld (packages clang, lld, llvm) instead of Ara's own LLVM 20 build,
# with the newlib and libgcc of Arch's riscv64-elf-gcc (rv64imafdc/lp64d multilib).
FYP_NEWLIB_LIB=/usr/riscv64-elf/lib/rv64imafdc/lp64d
FYP_LIBGCC_DIR="$(dirname "$(riscv64-elf-gcc -march=rv64imafdc -mabi=lp64d -print-libgcc-file-name)")"
export RISCV_PREFIX=/usr/bin/
export LLVM_FLAGS="--target=riscv64-unknown-elf --sysroot=/usr/riscv64-elf -rtlib=libgcc -L$FYP_NEWLIB_LIB -L$FYP_LIBGCC_DIR -march=rv64gcv_zfh_zvfh -mabi=lp64d -mno-relax -fuse-ld=lld"
# riscv-tests are compiled with GCC (Ara's riscv-tests flow); same libraries.
export RISCV_CC_GCC="riscv64-elf-gcc -L$FYP_NEWLIB_LIB -L$FYP_LIBGCC_DIR"
