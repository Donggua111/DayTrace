#!/bin/zsh

# Shared identity map for development tooling. The production Bundle ID is
# intentionally separate from the legacy Bundle ID and Native Messaging name.
DAYTRACE_PRODUCT_NAME="DayTrace"
DAYTRACE_LEGACY_BUNDLE_ID="com.daytrace.spike"
DAYTRACE_DEVELOPMENT_BUNDLE_ID="$DAYTRACE_LEGACY_BUNDLE_ID"
DAYTRACE_PRODUCTION_BUNDLE_ID="com.wudonggua.daytrace"
DAYTRACE_NATIVE_HOST_NAME="com.daytrace.spike"
DAYTRACE_CHROME_EXTENSION_ID="mmnoopahcchjobiajnhembdlipkhbjgo"
DAYTRACE_NATIVE_HOST_RELATIVE_PATH="Library/Application Support/DayTrace/Spike/Development/DayTraceNativeHost"
