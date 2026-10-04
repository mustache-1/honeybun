#!/usr/bin/env ruby
# Adds Honeybun's native pieces to the Xcode project: the widget extension, Siri shortcuts, push entitlements
# and the App Group. Safe to run more than once. Run it before `pod install`:
#   gem install xcodeproj   (CocoaPods already includes it)
#   ruby scripts/setup_native.rb
require 'xcodeproj'

root = File.expand_path('../ios/App', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'App.xcodeproj'))
app = project.targets.find { |t| t.name == 'App' } or abort('App target not found')
main = project.main_group

def group_for(main, name)
  g = main[name] || main.new_group(name, name)
  g.set_path(name) if g.path.nil?
  g
end

def ensure_file(group, name)
  group.files.find { |f| f.path == name } || group.new_file(name)
end

def add_source(target, ref)
  return if target.source_build_phase.files_references.include?(ref)
  target.add_file_references([ref])
end

app_group = group_for(main, 'App')
shared_group = group_for(main, 'Shared')
widget_group = group_for(main, 'HoneybunWidget')

# app target: native plugin, Siri shortcuts, shared code, entitlements
%w[BiometricLock.swift MainViewController.swift HoneybunNative.swift HoneybunIntents.swift].each { |n| add_source(app, ensure_file(app_group, n)) }
shared_ref = ensure_file(shared_group, 'HoneybunShared.swift')
add_source(app, shared_ref)
ensure_file(app_group, 'App.entitlements')
app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'App/App.entitlements'
  c.build_settings['ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES'] = 'AppIcon-Classic' # the main icon is the seasonal one; the normal bunny is the alternate the website switches to after Halloween (HoneybunNative.setIcon)
end

# widget extension target
widget = project.targets.find { |t| t.name == 'HoneybunWidget' }
unless widget
  widget = project.new_target(:app_extension, 'HoneybunWidget', :ios, '16.0', nil, :swift)
  add_source(widget, ensure_file(widget_group, 'HoneybunWidget.swift'))
  add_source(widget, shared_ref)
  ensure_file(widget_group, 'Info.plist')
  ensure_file(widget_group, 'HoneybunWidget.entitlements')
  widget.build_configurations.each do |c|
    s = c.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = 'me.honeybun.app.widget'
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['INFOPLIST_FILE'] = 'HoneybunWidget/Info.plist'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = 'HoneybunWidget/HoneybunWidget.entitlements'
    s['MARKETING_VERSION'] = '1.0'
    s['CURRENT_PROJECT_VERSION'] = '1'
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    s['SKIP_INSTALL'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  end
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  bf = embed.add_file_reference(widget.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  app.add_dependency(widget)
  # keep the extension embed step ahead of CocoaPods' "Embed Pods Frameworks" script, or Xcode reports a build cycle
  pods = app.build_phases.find { |ph| ph.respond_to?(:name) && ph.name.to_s.include?('Embed Pods Frameworks') }
  if pods
    app.build_phases.delete(embed)
    app.build_phases.insert(app.build_phases.index(pods), embed)
  end
end

project.save
puts 'Honeybun native targets are set up.'
