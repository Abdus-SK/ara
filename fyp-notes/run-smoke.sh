#!/bin/bash
# Ara smoke tests (the CI set) on the FYP CVA6.
# Usage: bash fyp-notes/run-smoke.sh [step] [config]
#   step:   apps | verilate | simv | rvtests | all   (default all)
#   config: a file in config/ without .mk            (default 2_lanes)
# Logs go to fyp-notes/logs/, one per step, with tool versions at the top.
STEP=${1:-all}
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." || exit 1
export ARA_CONFIGURATION=${2:-2_lanes}
source fyp-notes/ara-env.sh
CFG=$ARA_CONFIGURATION
APPS="hello_world imatmul fmatmul"
LOGS=fyp-notes/logs
mkdir -p "$LOGS"
VTOP=hardware/build/verilator/Vara_tb_verilator

header() {
  echo "# $(date '+%F %T')  step=$1  config=$CFG"
  echo "# ara  $(git rev-parse --short HEAD)  cva6 $(git -C "$CVA6_ROOT" rev-parse --short HEAD)"
  echo "# $("$veril_path/verilator" --version)"
  echo "# $(clang --version | head -1)"
  echo "# $(riscv64-elf-gcc --version | head -1)"
}

do_apps() {
  for a in $APPS; do
    rm -f apps/bin/$a apps/bin/$a.dump
    { header apps; make -C apps bin/$a; echo "exit=$?"; } 2>&1 | tee "$LOGS/build-$a-$CFG.log"
  done
}

do_verilate() {
  { header verilate; time make -C hardware verilate; echo "exit=$?"; } 2>&1 | tee "$LOGS/verilate-$CFG.log"
}

do_simv() {
  for a in $APPS; do
    { header simv; time make -C hardware simv app=$a; echo "exit=$?"; } 2>&1 | tee "$LOGS/simv-$a-$CFG.log"
  done
}

do_rvtests() {
  local log="$LOGS/riscv-tests-$CFG.log" pass=0 fail=0 t
  { header rvtests; make -C apps riscv_tests; echo "build exit=$?"; } 2>&1 | tee "$log"
  mkdir -p hardware/build/rvtests
  for t in apps/bin/rv64*-ara-*; do
    case $t in *.dump) continue;; esac
    if "$VTOP" -l ram,"$t",elf > "hardware/build/rvtests/$(basename "$t").trace" 2>&1; then
      pass=$((pass+1)); echo "PASS $(basename "$t")"
    else
      fail=$((fail+1)); echo "FAIL $(basename "$t")"
    fi
  done 2>&1 | tee -a "$log"
  echo "riscv-tests: $(grep -c '^PASS' "$log") passed, $(grep -c '^FAIL' "$log") failed" | tee -a "$log"
}

case $STEP in
  apps) do_apps ;;
  verilate) do_verilate ;;
  simv) do_simv ;;
  rvtests) do_rvtests ;;
  all) do_apps; do_verilate; do_simv; do_rvtests ;;
  *) echo "unknown step: $STEP"; exit 1 ;;
esac
