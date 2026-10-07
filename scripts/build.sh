#!/bin/sh
set -eu
TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
[ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
export DEVECO_SDK_HOME="$TASK_DEVECO/sdk"
export JAVA_HOME="$TASK_DEVECO/jbr"
export PATH="$TASK_DEVECO/tools/node/bin:$PATH"
TASK_ACTION=${1:-assembleHap}
TASK_TARGET=${2:-default}
TASK_BUILD_MODE=${3:-debug}
case "$TASK_BUILD_MODE" in
  debug|release) ;;
  *) echo "Build mode must be debug or release" >&2; exit 2 ;;
esac
if [ "$TASK_ACTION" = "assembleApp" ]; then
  exec "$TASK_DEVECO/tools/node/bin/node" "$TASK_DEVECO/tools/hvigor/bin/hvigorw.js" --mode project -p product=default -p "buildMode=$TASK_BUILD_MODE" "$TASK_ACTION" --no-daemon
fi
exec "$TASK_DEVECO/tools/node/bin/node" "$TASK_DEVECO/tools/hvigor/bin/hvigorw.js" --mode module -p product=default -p "module=entry@$TASK_TARGET" -p "buildMode=$TASK_BUILD_MODE" "$TASK_ACTION" --no-daemon
