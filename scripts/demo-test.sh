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
./scripts/build.sh > /tmp/elvacos-demo-main-build.txt 2>&1
./scripts/build.sh assembleHap ohosTest > /tmp/elvacos-demo-native-test-build.txt 2>&1
for TASK_HAP in entry/build/default/outputs/default/entry-default-signed.hap entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap; do
  TASK_INSTALL_OUTPUT=$(run_hdc install "$TASK_HAP")
  echo "$TASK_INSTALL_OUTPUT"
  echo "$TASK_INSTALL_OUTPUT" | rg 'install bundle successfully' >/dev/null
done
TASK_REPORT=$(mktemp)
trap 'rm -f "$TASK_REPORT"' EXIT
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyDemoTestRunner -s timeout 60000 > "$TASK_REPORT"
cat "$TASK_REPORT"
rg 'Tests run: 5, Failure: 0, Error: 0, Pass: 5, Ignore: 0' "$TASK_REPORT"
