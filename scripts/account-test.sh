#!/bin/sh
set -eu
if [ "${ELVACOS_DEVICE_TEST_LOCKED:-0}" != "1" ]; then
  exec python3 scripts/device_test_lock.py sh "$0" "$@"
fi
TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
[ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
TASK_HDC="$TASK_DEVECO/sdk/default/openharmony/toolchains/hdc"
if [ -z "${HDC_TARGET_ID:-}" ]; then
  "$TASK_HDC" list targets
  echo 'Set HDC_TARGET_ID to the unlocked test device before running real account integration.' >&2
  exit 2
fi
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
# Explicit production login; saves the ordinary local login state if successful.
# Does not modify business records or revoke authorization.
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyAccountTestRunner -s timeout 60000 > "$TASK_REPORT"
cat "$TASK_REPORT"
rg 'Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0' "$TASK_REPORT"
