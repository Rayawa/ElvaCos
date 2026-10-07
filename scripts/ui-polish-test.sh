#!/bin/sh
set -eu
if [ "${ELVACOS_DEVICE_TEST_LOCKED:-0}" != "1" ]; then
  exec python3 scripts/device_test_lock.py "$0" "$@"
fi
TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
[ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
TASK_HDC="$TASK_DEVECO/sdk/default/openharmony/toolchains/hdc"
run_hdc() {
  if [ -n "${HDC_TARGET_ID:-}" ]; then "$TASK_HDC" -t "$HDC_TARGET_ID" "$@";
  else "$TASK_HDC" "$@"; fi
}
install_hap() {
  TASK_INSTALL_OUTPUT=$(run_hdc install "$1")
  echo "$TASK_INSTALL_OUTPUT"
  echo "$TASK_INSTALL_OUTPUT" | rg 'install bundle successfully' >/dev/null
}
./scripts/build.sh
./scripts/build.sh assembleHap ohosTest
install_hap entry/build/default/outputs/default/entry-default-signed.hap
install_hap entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
run_hdc shell aa force-stop top.rayawa.elvacos
TASK_REPORT=$(mktemp)
trap 'rm -f "$TASK_REPORT"' EXIT
# Only changes temporary UI selections; domain checks use isolated objects.
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyUiPolishTestRunner -s timeout 120000 > "$TASK_REPORT"
cat "$TASK_REPORT"
rg 'Tests run: 7, Failure: 0, Error: 0, Pass: 7, Ignore: 0' "$TASK_REPORT"
