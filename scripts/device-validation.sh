#!/bin/sh
# One isolated build for selected serial suites; always restore the normal HAPs.
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$TASK_ROOT"
if [ "${ELVACOS_DEVICE_TEST_LOCKED:-0}" != 1 ]; then
  exec python3 scripts/device_test_lock.py "$0" "$@"
fi
: "${HDC_TARGET_ID:?Set HDC_TARGET_ID to the device under test}"
[ "$#" -gt 0 ] || { echo 'Select: responsive ui layout performance native' >&2; exit 2; }
if [ -n "${DEVICE_TEST_CLASS:-}" ]; then
  [ "$#" = 1 ] || { echo 'A class filter requires exactly one suite' >&2; exit 2; }
  : "${EXPECTED_CASE_COUNT:?Set EXPECTED_CASE_COUNT for a filtered run}"
fi
for TASK_SUITE in "$@"; do
  case "$TASK_SUITE" in
    responsive)
      case "${EXPECTED_DEVICE_TYPE:-}" in
        phone|tablet|2in1) ;;
        *) echo 'Set EXPECTED_DEVICE_TYPE to phone, tablet or 2in1' >&2; exit 2 ;;
      esac ;;
    ui|layout|performance|native) ;;
    *) echo "Unknown suite: $TASK_SUITE" >&2; exit 2 ;;
  esac
done
if [ -n "${HARMONYOS_COMMAND_LINE_TOOLS:-}" ]; then
  TASK_SDK="$HARMONYOS_COMMAND_LINE_TOOLS/sdk"
else
  TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
  [ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
  TASK_SDK="$TASK_DEVECO/sdk"
fi
TASK_HDC="$TASK_SDK/default/openharmony/toolchains/hdc"
TASK_RUN="$TASK_ROOT/build/verification/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TASK_RUN"
run_hdc() { "$TASK_HDC" -t "$HDC_TARGET_ID" "$@"; }
run_selected_test() {
  set -- shell aa test -b top.rayawa.elvacos -m entry_test -s unittest "$TASK_RUNNER" \
    -s expectedDeviceType "${EXPECTED_DEVICE_TYPE:-unspecified}" -s profile "${DEVICE_PROFILE:-false}" -s timeout 300000
  if [ -n "${DEVICE_TEST_CLASS:-}" ]; then
    set -- "$@" -s class "$DEVICE_TEST_CLASS"
  fi
  run_hdc "$@"
}
install_hap() {
  TASK_OUTPUT=$(run_hdc install "$1")
  echo "$TASK_OUTPUT"
  echo "$TASK_OUTPUT" | rg 'install bundle successfully' >/dev/null
}
TASK_MAIN=entry/build/default/outputs/default/entry-default-signed.hap
TASK_TEST=entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
./scripts/build.sh > "$TASK_RUN/build-normal.log" 2>&1
./scripts/build.sh assembleHap ohosTest > "$TASK_RUN/build-normal-test.log" 2>&1
for TASK_HAP in "$TASK_MAIN" "$TASK_TEST"; do
  [ -f "$TASK_HAP" ] || { echo "Missing local signature: $TASK_HAP" >&2; exit 1; }
done
TASK_REPLICA=$(python3 scripts/prepare_device_validation.py)
echo "$TASK_REPLICA" > "$TASK_RUN/replica-path.txt"
(cd "$TASK_REPLICA" && ./scripts/build.sh) > "$TASK_RUN/build-isolated.log" 2>&1
(cd "$TASK_REPLICA" && ./scripts/build.sh assembleHap ohosTest) > "$TASK_RUN/build-isolated-test.log" 2>&1
restore_normal() {
  TASK_RESULT=$?
  trap - EXIT INT TERM
  # Do not start EntryAbility: the normal build would open personal data.
  run_hdc shell aa force-stop top.rayawa.elvacos > "$TASK_RUN/restore.log" 2>&1 || true
  if ! install_hap "$TASK_ROOT/$TASK_MAIN" >> "$TASK_RUN/restore.log" 2>&1 ||
     ! install_hap "$TASK_ROOT/$TASK_TEST" >> "$TASK_RUN/restore.log" 2>&1; then
    echo "Normal HAP restoration failed: $TASK_RUN/restore.log" >&2
    TASK_RESULT=1
  fi
  echo "Device evidence: $TASK_RUN"
  exit "$TASK_RESULT"
}
trap restore_normal EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
install_hap "$TASK_REPLICA/$TASK_MAIN" > "$TASK_RUN/install.log" 2>&1
install_hap "$TASK_REPLICA/$TASK_TEST" >> "$TASK_RUN/install.log" 2>&1
run_hdc shell param get const.product.devicetype > "$TASK_RUN/device-type.txt"
for TASK_SUITE in "$@"; do
  case "$TASK_SUITE" in
    responsive)
      TASK_RUNNER=OpenHarmonyResponsiveUITestRunner
      TASK_COUNT=4
      [ "$EXPECTED_DEVICE_TYPE" != 2in1 ] || TASK_COUNT=5 ;;
    ui) TASK_RUNNER=OpenHarmonyUITestRunner; TASK_COUNT=20 ;;
    layout) TASK_RUNNER=OpenHarmonyFidelityUITestRunner; TASK_COUNT=4 ;;
    performance) TASK_RUNNER=OpenHarmonyPerformanceTestRunner; TASK_COUNT=3 ;;
    native) TASK_RUNNER=OpenHarmonyTestRunner; TASK_COUNT=55 ;;
  esac
  TASK_COUNT=${EXPECTED_CASE_COUNT:-$TASK_COUNT}
  run_hdc shell aa force-stop top.rayawa.elvacos >> "$TASK_RUN/install.log" 2>&1
  if [ "$TASK_SUITE" = performance ]; then
    python3 scripts/measure_startup.py "$TASK_HDC" "$HDC_TARGET_ID" "$TASK_RUN" > "$TASK_RUN/startup.log" 2>&1
    run_hdc shell aa force-stop top.rayawa.elvacos >> "$TASK_RUN/install.log" 2>&1
  fi
  TASK_REPORT="$TASK_RUN/$TASK_SUITE.log"
  run_selected_test > "$TASK_REPORT" 2>&1
  python3 scripts/collect_device_screens.py "$TASK_HDC" "$HDC_TARGET_ID" "$TASK_REPORT" "$TASK_RUN/screens" > "$TASK_RUN/$TASK_SUITE-screens.log" 2>&1
  if ! rg "Tests run: $TASK_COUNT, Failure: 0, Error: 0, Pass: $TASK_COUNT, Ignore: 0" "$TASK_REPORT"; then
    tail -60 "$TASK_REPORT"
    exit 1
  fi
done
