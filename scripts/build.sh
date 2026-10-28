#!/bin/sh
set -eu
TASK_REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -n "${HARMONYOS_COMMAND_LINE_TOOLS:-}" ]; then
  TASK_TOOLS=$HARMONYOS_COMMAND_LINE_TOOLS
  TASK_NODE="$TASK_TOOLS/tool/node/bin/node"
  TASK_HVIGOR="$TASK_TOOLS/hvigor/bin/hvigorw.js"
  export DEVECO_SDK_HOME="$TASK_TOOLS/sdk"
else
  TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
  [ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
  TASK_NODE="$TASK_DEVECO/tools/node/bin/node"
  TASK_HVIGOR="$TASK_DEVECO/tools/hvigor/bin/hvigorw.js"
  export DEVECO_SDK_HOME="$TASK_DEVECO/sdk"
  export JAVA_HOME="$TASK_DEVECO/jbr"
fi
if [ ! -x "$TASK_NODE" ] || [ ! -f "$TASK_HVIGOR" ]; then
  echo "HarmonyOS tools not found. Set DEVECO_HOME or HARMONYOS_COMMAND_LINE_TOOLS." >&2
  exit 1
fi
export PATH="$(dirname -- "$TASK_NODE"):$PATH"
cd "$TASK_REPO"
"$TASK_NODE" "$TASK_REPO/scripts/configure_sdk.cjs"
TASK_ACTION=${1:-assembleHap}
TASK_TARGET=${2:-default}
TASK_BUILD_MODE=${3:-debug}
case "$TASK_BUILD_MODE" in
  debug|release) ;;
  *) echo "Build mode must be debug or release" >&2; exit 2 ;;
esac
if [ "$TASK_ACTION" = "assembleApp" ]; then
  exec "$TASK_NODE" "$TASK_HVIGOR" --mode project -p product=default -p "buildMode=$TASK_BUILD_MODE" "$TASK_ACTION" --no-daemon
fi
exec "$TASK_NODE" "$TASK_HVIGOR" --mode module -p product=default -p "module=entry@$TASK_TARGET" -p "buildMode=$TASK_BUILD_MODE" "$TASK_ACTION" --no-daemon
