#!/usr/bin/env ruby
# Static checks for the Xcode project, runnable anywhere Ruby + the xcodeproj gem exist (no Xcode needed):
#   gem install xcodeproj && ruby scripts/check_project.rb
# Catches the mistakes that broke fresh clones before: Swift files on disk but not in the App target,
# duplicate or dangling file references, a missing shared App scheme / workspace entry, and a missing UIScene manifest.
require 'xcodeproj'

root = File.expand_path('../ios/App', __dir__)
errors = []
fail_with = ->(m) { errors << m }

proj_path = File.join(root, 'App.xcodeproj')
project = Xcodeproj::Project.open(proj_path)
app = project.targets.find { |t| t.name == 'App' } or abort('App target not found')
widget = project.targets.find { |t| t.name == 'HoneybunWidget' }

# sources: every Swift file in the app folders is compiled into App, none twice, none dangling
app_paths = app.source_build_phase.files.map { |f| f.file_ref&.real_path.to_s }
(app_paths.select { |p| app_paths.count(p) > 1 }.uniq).each { |p| fail_with.("App compiles #{p} more than once") }
app_paths.reject { |p| File.exist?(p) }.each { |p| fail_with.("App Sources lists a file that is not on disk: #{p}") }
disk = Dir[File.join(root, '{App,HoneybunSwiftUI,Shared}', '**', '*.swift')].map { |p| File.expand_path(p) }
(disk - app_paths.map { |p| File.expand_path(p) }).each { |p| fail_with.("Swift file is not in the App target: #{p.sub(root + '/', '')}") }
names = disk.map { |p| File.basename(p) }
names.select { |n| names.count(n) > 1 }.uniq.each { |n| fail_with.("two Swift files share the name #{n} (one module, ambiguous)") }

# the widget only takes its own file and the shared one
if widget
  w = widget.source_build_phase.files.map { |f| File.basename(f.file_ref.path.to_s) }.sort
  fail_with.("HoneybunWidget sources should be HoneybunShared.swift + HoneybunWidget.swift, found #{w.inspect}") unless w == %w[HoneybunShared.swift HoneybunWidget.swift]
else
  fail_with.('HoneybunWidget target not found')
end
fail_with.('App does not embed the widget') unless app.copy_files_build_phases.any? { |b| b.files.any? { |f| f.display_name.to_s.include?('HoneybunWidget') } }

# file references: no duplicate object ids, no file reference twice for the same path in the same group
raw = File.read(File.join(proj_path, 'project.pbxproj'))
ids = raw.scan(/^\t\t([0-9A-F]{24}) \/\*.*?\*\/ = \{/).flatten
ids.select { |i| ids.count(i) > 1 }.uniq.each { |i| fail_with.("duplicate object id #{i}") }
project.groups.each do |g|
  paths = g.files.map(&:path)
  paths.select { |p| paths.count(p) > 1 }.uniq.each { |p| fail_with.("group #{g.display_name} references #{p} twice") }
end

# deployment targets: every target at least iOS 15, the app and Pods at exactly the Podfile's value
project.targets.each do |t|
  t.build_configurations.each do |c|
    v = c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
    fail_with.("#{t.name} #{c.name}: IPHONEOS_DEPLOYMENT_TARGET #{v.inspect} is below 15.0") if v && v.to_f < 15.0
  end
end
fail_with.('Podfile is not on iOS 15.0') unless File.read(File.join(root, 'Podfile')) =~ /platform :ios, '15\.0'/

# shared App scheme + workspace
scheme = File.join(proj_path, 'xcshareddata', 'xcschemes', 'App.xcscheme')
if File.exist?(scheme)
  fail_with.('App.xcscheme does not build the App target') unless File.read(scheme).include?(%(BlueprintName = "App"))
else
  fail_with.('shared scheme App.xcscheme is missing (xcodebuild -list would not show App)')
end
ws = File.join(root, 'App.xcworkspace', 'contents.xcworkspacedata')
if File.exist?(ws)
  t = File.read(ws)
  fail_with.('App.xcworkspace does not reference App.xcodeproj') unless t.include?('group:App.xcodeproj')
  fail_with.('App.xcworkspace does not reference Pods/Pods.xcodeproj') unless t.include?('group:Pods/Pods.xcodeproj')
else
  fail_with.('App.xcworkspace/contents.xcworkspacedata is missing')
end

# UIScene lifecycle (required by the iOS 26+ SDKs): manifest names SceneDelegate, the window is built there, not in AppDelegate
info = File.read(File.join(root, 'App', 'Info.plist'))
fail_with.('Info.plist has no UIApplicationSceneManifest') unless info.include?('UIApplicationSceneManifest')
fail_with.('Info.plist scene delegate is not $(PRODUCT_MODULE_NAME).SceneDelegate') unless info.include?('$(PRODUCT_MODULE_NAME).SceneDelegate')
fail_with.('Info.plist sets UIMainStoryboardFile: Classic would open first') if info.include?('UIMainStoryboardFile')
sd = File.join(root, 'App', 'SceneDelegate.swift')
fail_with.('App/SceneDelegate.swift is missing') unless File.exist?(sd)
fail_with.('SceneDelegate must create the root with HoneybunRoot.shared.makeRoot()') unless File.exist?(sd) && File.read(sd).include?('HoneybunRoot.shared.makeRoot()')
ad = File.read(File.join(root, 'App', 'AppDelegate.swift'))
fail_with.('AppDelegate still creates a UIWindow (scene owns it now)') if ad =~ /UIWindow\(/
fail_with.('AppDelegate still implements application(_:open:) / application(_:continue:), which iOS does not call with scenes') if ad =~ /application\(_ \w+: UIApplication, (open|continue)/

if errors.empty?
  puts "Xcode project checks passed (#{app_paths.size} App sources, #{project.targets.size} targets)."
else
  errors.each { |e| warn "ERROR: #{e}" }
  exit 1
end
