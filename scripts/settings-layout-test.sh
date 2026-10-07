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
install_hap() {
  TASK_INSTALL_OUTPUT=$(run_hdc install "$1")
  echo "$TASK_INSTALL_OUTPUT"
  echo "$TASK_INSTALL_OUTPUT" | rg 'install bundle successfully' >/dev/null
}
# Only the private clone contains the UI host; it never starts EntryAbility or opens personal.db.
./scripts/build.sh
./scripts/build.sh assembleHap ohosTest
TASK_ROOT=$(pwd)
TASK_CLONE=$(python3 scripts/prepare_settings_layout.py)
TASK_REPORT=$(mktemp)
TASK_INSTALLED=0
cleanup() {
  TASK_EXIT=$?
  trap - EXIT HUP INT TERM
  if [ "$TASK_INSTALLED" = "1" ]; then
    run_hdc shell aa force-stop top.rayawa.elvacos || true
    if ! install_hap "$TASK_ROOT/entry/build/default/outputs/default/entry-default-signed.hap" || ! install_hap "$TASK_ROOT/entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap"; then
      echo "Package restoration failed; recovery clone kept at $TASK_CLONE" >&2
      rm -f "$TASK_REPORT"
      exit 1
    fi
  fi
  rm -f "$TASK_REPORT"
  rm -rf "$TASK_CLONE"
  exit "$TASK_EXIT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
(cd "$TASK_CLONE" && ./scripts/build.sh && ./scripts/build.sh assembleHap ohosTest)
TASK_INSTALLED=1
install_hap "$TASK_CLONE/entry/build/default/outputs/default/entry-default-signed.hap"
install_hap "$TASK_CLONE/entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap"
run_hdc shell aa force-stop top.rayawa.elvacos
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonySettingsLayoutTestRunner -s timeout 210000 > "$TASK_REPORT"
cat "$TASK_REPORT"
rg 'Tests run: 5, Failure: 0, Error: 0, Pass: 5, Ignore: 0' "$TASK_REPORT"
