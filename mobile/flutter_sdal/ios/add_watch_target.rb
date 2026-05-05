#!/usr/bin/env ruby
# Adds SdalWatch watchOS application target to the Xcode project.
# Run: /opt/homebrew/opt/ruby/bin/ruby add_watch_target.rb

GEMS_DIR = '/opt/homebrew/Cellar/cocoapods/1.16.2_2/libexec/gems'
$LOAD_PATH.unshift("#{GEMS_DIR}/xcodeproj-1.27.0/lib")
$LOAD_PATH.unshift("#{GEMS_DIR}/claide-1.1.0/lib")
Dir["#{GEMS_DIR}/*/lib"].each { |p| $LOAD_PATH.unshift(p) unless $LOAD_PATH.include?(p) }
require 'xcodeproj'

PROJECT_PATH      = File.expand_path('../Runner.xcodeproj', __FILE__)
WATCH_NAME        = 'SdalWatch'
BUNDLE_ID         = "com.sdal.flutterSdal.#{WATCH_NAME}"
TEAM_ID           = '4P293R4B47'
DEPLOYMENT_TARGET = '8.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

# Skip if already added
if project.targets.any? { |t| t.name == WATCH_NAME }
  puts "Target '#{WATCH_NAME}' already exists — skipping."
  exit 0
end

# ─── Source file references ────────────────────────────────────────────────
# watch_group corresponds to the SdalWatch/ directory (path relative to ios/).
# All file paths inside are relative to their containing group — never prefixed
# with the parent group name, otherwise Xcode resolves them with double nesting.
watch_group = project.main_group.new_group(WATCH_NAME, WATCH_NAME)

# Add a file reference with correct group-relative path.
# rel_path uses '/' to separate sub-directory components.
# We create intermediate groups as needed, then add the file with only its
# basename (last component) as the path — keeping the sourceTree '<group>'
# resolution to the actual sub-directory path.
def add_watch_file(parent_group, rel_path)
  parts = rel_path.split('/')
  current = parent_group
  # Navigate / create intermediate directory groups (all but the last part)
  parts[0..-2].each do |dir|
    current = current[dir] || current.new_group(dir, dir)
  end
  # The file's path is just its filename, relative to its containing group.
  # The group hierarchy already encodes the subdirectory.
  current.new_file(parts.last)
end

swift_files = %w[
  App/SdalWatchApp.swift
  App/ContentView.swift
  Models/WatchModels.swift
  Networking/WatchAPIClient.swift
  Networking/WatchSessionManager.swift
  ViewModels/WatchViewModel.swift
  Views/FeedView.swift
  Views/MessagesView.swift
  Views/NotificationsView.swift
  Views/SharedComponents.swift
]

swift_refs  = swift_files.map { |f| add_watch_file(watch_group, f) }
assets_ref  = add_watch_file(watch_group, 'Assets.xcassets')
# Info.plist: file ref only (not added to resources — processed via INFOPLIST_FILE build setting)
_plist_ref  = add_watch_file(watch_group, 'Info.plist')

# ─── Create watchOS application target ────────────────────────────────────
target = project.new_target(:application, WATCH_NAME, :watchos, DEPLOYMENT_TARGET)

# Source files
sources_phase = target.source_build_phase
swift_refs.each { |ref| sources_phase.add_file_reference(ref) }

# Resources — asset catalog only (Info.plist is handled by the build system)
resources_phase = target.resources_build_phase
resources_phase.add_file_reference(assets_ref)

# ─── Build settings ────────────────────────────────────────────────────────
target.build_configurations.each do |config|
  s = config.build_settings
  s['SDKROOT']                         = 'watchos'
  s['TARGETED_DEVICE_FAMILY']          = '4'
  s['WATCHOS_DEPLOYMENT_TARGET']       = DEPLOYMENT_TARGET
  s['SWIFT_VERSION']                   = '5.0'
  s['PRODUCT_NAME']                    = WATCH_NAME
  s['PRODUCT_MODULE_NAME']             = WATCH_NAME
  s['PRODUCT_BUNDLE_IDENTIFIER']       = BUNDLE_ID
  s['DEVELOPMENT_TEAM']                = TEAM_ID
  s['INFOPLIST_FILE']                  = "#{WATCH_NAME}/Info.plist"
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['CODE_SIGN_STYLE']                 = 'Automatic'
  s['SKIP_INSTALL']                    = 'NO'
  s['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS']         = ['$(inherited)', '@executable_path/Frameworks']
  s['FLUTTER_BUILD_NAME']              = '1.0'
  s['FLUTTER_BUILD_NUMBER']            = '1'
  s['SUPPORTED_PLATFORMS']  = 'watchos watchsimulator'
  s['ONLY_ACTIVE_ARCH']     = (config.name == 'Debug') ? 'YES' : 'NO'
  # watchOS simulator does not support code-signing
  s['CODE_SIGNING_ALLOWED[sdk=watchsimulator*]'] = 'NO'
  s['CODE_SIGNING_REQUIRED[sdk=watchsimulator*]'] = 'NO'
  s['EXPANDED_CODE_SIGN_IDENTITY[sdk=watchsimulator*]'] = ''
end

# ─── WatchBridge.swift + WatchConnectivity for Runner (iOS side) ───────────
# NOTE: SdalWatch is NOT added as a PBXTargetDependency of Runner.
# Xcode 15+ (and 26 beta) ignores SDKROOT=watchos on embedded dependencies and
# compiles them with the iOS SDK. Instead, install_local.sh option 7 builds
# SdalWatch for watchOS separately and injects it into the Runner xcarchive.
runner = project.targets.find { |t| t.name == 'Runner' }
if runner
  runner_group = project.main_group['Runner'] ||
                 project.main_group.children.find { |g|
                   g.respond_to?(:path) && g.path == 'Runner'
                 }
  if runner_group
    # Only add WatchBridge.swift if it isn't already in the group
    unless runner_group.children.any? { |c| c.respond_to?(:path) && c.path.to_s == 'WatchBridge.swift' }
      bridge_ref = runner_group.new_file('WatchBridge.swift')
      runner.source_build_phase.add_file_reference(bridge_ref)
    end
  end

  runner_frameworks = runner.frameworks_build_phase
  already_has_wc = runner_frameworks.files.any? { |f|
    f.file_ref.respond_to?(:name) && f.file_ref.name.to_s.include?('WatchConnectivity')
  }
  unless already_has_wc
    wc_ref = project.frameworks_group.new_file(
      'System/Library/Frameworks/WatchConnectivity.framework'
    )
    wc_ref.source_tree = 'SDKROOT'
    runner_frameworks.add_file_reference(wc_ref)
  end
end

# WatchConnectivity framework for the watch target
watch_frameworks = target.frameworks_build_phase
wc_watch_ref = project.frameworks_group.new_file(
  'System/Library/Frameworks/WatchConnectivity.framework'
)
wc_watch_ref.source_tree = 'SDKROOT'
watch_frameworks.add_file_reference(wc_watch_ref)

project.save
puts "Done — '#{WATCH_NAME}' target added to #{PROJECT_PATH}"
