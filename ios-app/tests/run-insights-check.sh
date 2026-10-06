#!/bin/bash
# Compiles and runs the Smarter Honeybun insight checks on a Mac (same file list CI uses). From the repo root:  bash ios-app/tests/run-insights-check.sh
set -e
cd "$(dirname "$0")/.."
swiftc -D DEBUG -o /tmp/hbinsights \
  ios/App/HoneybunSwiftUI/Models/HBModels.swift \
  ios/App/HoneybunSwiftUI/Core/HBDates.swift \
  ios/App/HoneybunSwiftUI/Core/HBGoalStyle.swift \
  ios/App/HoneybunSwiftUI/Core/HBTogether.swift \
  ios/App/HoneybunSwiftUI/Core/HBInbox.swift \
  ios/App/HoneybunSwiftUI/Core/HBCatStyle.swift \
  ios/App/HoneybunSwiftUI/Core/HBPlan.swift \
  ios/App/HoneybunSwiftUI/Core/HBPlanAPI.swift \
  ios/App/HoneybunSwiftUI/Core/HBPasskeyKit.swift \
  ios/App/HoneybunSwiftUI/Core/HBPreviewData.swift \
  ios/App/HoneybunSwiftUI/Core/HBPreviewVariants.swift \
  ios/App/HoneybunSwiftUI/Core/HBMockServer.swift \
  ios/App/HoneybunSwiftUI/Core/HBReferralLink.swift \
  ios/App/HoneybunSwiftUI/Core/HBAPI.swift \
  ios/App/HoneybunSwiftUI/Core/HBOfflineCache.swift \
  ios/App/HoneybunSwiftUI/Core/HBSearchFilter.swift \
  ios/App/HoneybunSwiftUI/Core/HBProgress.swift \
  ios/App/HoneybunSwiftUI/Core/HBHeadsUp.swift \
  ios/App/HoneybunSwiftUI/Core/HBPendingQueue.swift \
  ios/App/HoneybunSwiftUI/Core/HBSplit.swift \
  ios/App/HoneybunSwiftUI/Core/HBInsights.swift \
  tests/InsightsFlowCheck/main.swift
/tmp/hbinsights
