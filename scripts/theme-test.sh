#!/bin/sh
set -eu
if [ "${ELVACOS_DEVICE_TEST_LOCKED:-0}" != "1" ]; then
  exec python3 scripts/device_test_lock.py "$0" "$@"
fi
TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
[ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
TASK_HDC="$TASK_DEVECO/sdk/default/openharmony/toolchains/hdc"
run_hdc() {
  if [ -n "${HDC_TARGET_ID:-}" ]; then "$TASK_HDC" -t "$HDC_TARGET_ID" "$@"; else "$TASK_HDC" "$@"; fi
}
install_hap() {
  TASK_INSTALL_OUTPUT=$(run_hdc install "$1")
  echo "$TASK_INSTALL_OUTPUT"
  echo "$TASK_INSTALL_OUTPUT" | rg 'install bundle successfully' >/dev/null
}
TASK_LOG=$(mktemp)
./scripts/build.sh > "$TASK_LOG" 2>&1 || { cat "$TASK_LOG"; exit 1; }
./scripts/build.sh assembleHap ohosTest >> "$TASK_LOG" 2>&1 || { cat "$TASK_LOG"; exit 1; }
TASK_ROOT=$(pwd)
TASK_CLONE=$(python3 scripts/prepare_theme_validation.py)
TASK_INSTALLED=0
cleanup() {
  TASK_EXIT=$?
  trap - EXIT HUP INT TERM
  if [ "$TASK_INSTALLED" = "1" ]; then
    run_hdc shell aa force-stop top.rayawa.elvacos || true
    if ! install_hap "$TASK_ROOT/entry/build/default/outputs/default/entry-default-signed.hap" || ! install_hap "$TASK_ROOT/entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap"; then
      echo "Package restoration failed; recovery clone kept at $TASK_CLONE" >&2
      exit 1
    fi
  fi
  rm -f "$TASK_LOG"
  rm -rf "$TASK_CLONE"
  exit "$TASK_EXIT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
(cd "$TASK_CLONE" && ./scripts/build.sh && ./scripts/build.sh assembleHap ohosTest) >> "$TASK_LOG" 2>&1 || { cat "$TASK_LOG"; exit 1; }
rg 'BUILD SUCCESSFUL' "$TASK_LOG"
TASK_INSTALLED=1
install_hap "$TASK_CLONE/entry/build/default/outputs/default/entry-default-signed.hap"
install_hap "$TASK_CLONE/entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap"
mkdir -p docs/validation
run_hdc shell aa force-stop top.rayawa.elvacos
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyThemeTestRunner -s timeout 240000 > docs/validation/theme-switch-api26-report.txt
cat docs/validation/theme-switch-api26-report.txt
rg 'Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0' docs/validation/theme-switch-api26-report.txt
run_hdc shell aa force-stop top.rayawa.elvacos
run_hdc shell aa test -b top.rayawa.elvacos -m entry_test -s unittest OpenHarmonyThemeRestoreTestRunner -s timeout 30000 > docs/validation/theme-restore-api26-report.txt
cat docs/validation/theme-restore-api26-report.txt
rg 'Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0' docs/validation/theme-restore-api26-report.txt
if [ -n "${THEME_SCREENSHOT_DIR:-}" ]; then
  mkdir -p "$THEME_SCREENSHOT_DIR"
  for color in blue green pink orange red; do
    for mode in sky mist; do
      run_hdc file recv "/data/app/el2/100/base/top.rayawa.elvacos/cache/elvacos-theme-$color-$mode.png" "$THEME_SCREENSHOT_DIR/$color-$mode.png"
    done
  done
  run_hdc file recv /data/app/el2/100/base/top.rayawa.elvacos/cache/elvacos-theme-narrow-large.png "$THEME_SCREENSHOT_DIR/narrow-large.png"
fi
