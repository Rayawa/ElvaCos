#!/bin/sh
set -eu
TASK_DEVECO=${DEVECO_HOME:-"$HOME/Applications/DevEco-Studio.app/Contents"}
[ -d "$TASK_DEVECO/Contents" ] && TASK_DEVECO="$TASK_DEVECO/Contents"
export DEVECO_SDK_HOME="$TASK_DEVECO/sdk"
export JAVA_HOME="$TASK_DEVECO/jbr"
export PATH="$TASK_DEVECO/tools/node/bin:$PATH"
exec "$TASK_DEVECO/tools/node/bin/node" "$TASK_DEVECO/tools/hvigor/bin/hvigorw.js" --mode module -p product=default -p "module=entry@${2:-default}" "${1:-assembleHap}" --no-daemon
