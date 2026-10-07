#!/bin/sh
set -eu
if [ "${ELVACOS_DEVICE_TEST_LOCKED:-0}" != "1" ]; then
  exec python3 scripts/device_test_lock.py "$0" "$@"
fi
TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
[ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
TASK_HDC="$TASK_DEVECO/sdk/default/openharmony/toolchains/hdc"
run_hdc() {
  if [ -n "${HDC_TARGET_ID:-}" ]; then
    "$TASK_HDC" -t "$HDC_TARGET_ID" "$@"
  else
    "$TASK_HDC" "$@"
  fi
}
./scripts/build.sh
./scripts/build.sh assembleHap ohosTest
run_hdc install entry/build/default/outputs/default/entry-default-signed.hap
run_hdc install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
run_hdc shell aa force-stop top.rayawa.elvacos
TASK_REPORT=$(mktemp)
trap 'rm -f "$TASK_REPORT"' EXIT
# Read-only layout coverage; requires an unlocked screen and no concurrent device UI task.
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyFidelityUITestRunner -s timeout 180000 > "$TASK_REPORT"
cat "$TASK_REPORT"
rg 'Tests run: 4, Failure: 0, Error: 0, Pass: 4, Ignore: 0' "$TASK_REPORT"
