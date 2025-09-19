#!/bin/bash
export ANDROID_HOME=/workspace/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/workspace/gradle-8.4/bin
gradle "$@"