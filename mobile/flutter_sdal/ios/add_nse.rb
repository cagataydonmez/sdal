#!/usr/bin/env ruby
# Adds SdalNotificationExtension target to the Xcode project.
# Run: /opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/bin/ruby add_nse.rb

$LOAD_PATH.unshift('/opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/gems/xcodeproj-1.27.0/lib')
require 'xcodeproj'

PROJECT_PATH    = File.expand_path('../Runner.xcodeproj', __FILE__)
EXT_NAME        = 'SdalNotificationExtension'
BUNDLE_ID       = "com.sdal.flutterSdal.#{EXT_NAME}"
TEAM_ID         = '4P293R4B47'
DEPLOYMENT_TARGET = '15.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

# Skip if already added
if project.targets.any? { |t| t.name == EXT_NAME }
  puts "Target '#{EXT_NAME}' already exists — skipping."
  exit 0
end

# Add group + files
ext_group = project.main_group.new_group(EXT_NAME, EXT_NAME)
swift_ref = ext_group.new_file('SdalNotificationExtension/NotificationService.swift')
plist_ref  = ext_group.new_file('SdalNotificationExtension/Info.plist')

# Create target
target = project.new_target(:app_extension, EXT_NAME, :ios, DEPLOYMENT_TARGET)

# Build phases
sources_phase = target.source_build_phase
sources_phase.add_file_reference(swift_ref)

resources_phase = target.resources_build_phase
resources_phase.add_file_reference(plist_ref)

# Build settings for all configs
target.build_configurations.each do |config|
  s = config.build_settings
  s['SWIFT_VERSION']                  = '5.0'
  s['PRODUCT_BUNDLE_IDENTIFIER']      = BUNDLE_ID
  s['DEVELOPMENT_TEAM']               = TEAM_ID
  s['IPHONEOS_DEPLOYMENT_TARGET']     = DEPLOYMENT_TARGET
  s['INFOPLIST_FILE']                 = "#{EXT_NAME}/Info.plist"
  s['CODE_SIGN_STYLE']                = 'Automatic'
  s['TARGETED_DEVICE_FAMILY']         = '1,2'
  s['SKIP_INSTALL']                   = 'YES'
  s['CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]'] = 'NO'
  s['CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]'] = 'NO'
  s['EXPANDED_CODE_SIGN_IDENTITY[sdk=iphonesimulator*]'] = ''
end

# Make Runner depend on the extension (embed it)
runner = project.targets.find { |t| t.name == 'Runner' }
if runner
  runner.add_dependency(target)
  embed_phase = runner.build_phases.find { |p|
    p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.dst_subfolder_spec == '13'
  }
  unless embed_phase
    embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed_phase.name = 'Embed App Extensions'
    embed_phase.dst_subfolder_spec = '13'
    runner.build_phases << embed_phase
  end
  ext_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  ext_file.file_ref = target.product_reference
  ext_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  embed_phase.files << ext_file
end

project.save
puts "Done — '#{EXT_NAME}' target added to #{PROJECT_PATH}"
