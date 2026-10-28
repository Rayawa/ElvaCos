#!/bin/sh
set -eu
if [ "${ELVACOS_DEVICE_TEST_LOCKED:-0}" != "1" ]; then
  exec python3 scripts/device_test_lock.py "$0" "$@"
fi
: "${HDC_TARGET_ID:?Set HDC_TARGET_ID to the device under test}"
: "${EXPECTED_DEVICE_TYPE:?Set EXPECTED_DEVICE_TYPE to phone, tablet or 2in1}"
case "$EXPECTED_DEVICE_TYPE" in
  phone|tablet) TASK_COUNT=3 ;;
  2in1) TASK_COUNT=4 ;;
  *) echo "EXPECTED_DEVICE_TYPE must be phone, tablet or 2in1" >&2; exit 2 ;;
esac
if [ -n "${HARMONYOS_COMMAND_LINE_TOOLS:-}" ]; then
  TASK_SDK="$HARMONYOS_COMMAND_LINE_TOOLS/sdk"
else
  TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
  [ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
  TASK_SDK="$TASK_DEVECO/sdk"
fi
TASK_HDC="$TASK_SDK/default/openharmony/toolchains/hdc"
run_hdc() {
  "$TASK_HDC" -t "$HDC_TARGET_ID" "$@"
}
run_hdc shell param get const.product.devicetype
./scripts/build.sh
./scripts/build.sh assembleHap ohosTest
for TASK_HAP in entry/build/default/outputs/default/entry-default-signed.hap entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap; do
  if [ ! -f "$TASK_HAP" ]; then
    echo "Missing signed HAP: $TASK_HAP. Configure a local development signature before device testing." >&2
    exit 1
  fi
  TASK_INSTALL_OUTPUT=$(run_hdc install "$TASK_HAP")
  echo "$TASK_INSTALL_OUTPUT"
  echo "$TASK_INSTALL_OUTPUT" | rg 'install bundle successfully' >/dev/null
done
TASK_REPORT=$(mktemp)
trap 'rm -f "$TASK_REPORT"' EXIT
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyResponsiveUITestRunner -s expectedDeviceType "$EXPECTED_DEVICE_TYPE" -s timeout 180000 > "$TASK_REPORT"
cat "$TASK_REPORT"
rg "Tests run: $TASK_COUNT, Failure: 0, Error: 0, Pass: $TASK_COUNT, Ignore: 0" "$TASK_REPORT"
