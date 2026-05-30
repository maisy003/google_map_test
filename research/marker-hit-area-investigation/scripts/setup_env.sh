#!/usr/bin/env bash
# Source this file: `source scripts/setup_env.sh`
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
export AVD_NAME="MarkerHitTest_API36"
echo "env ready: JAVA=$(java -version 2>&1 | head -1)"
echo "          adb=$(adb --version 2>&1 | head -1)"
echo "          AVD=$AVD_NAME"
