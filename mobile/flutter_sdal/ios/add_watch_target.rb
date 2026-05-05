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
DEPLOYMENT_TARGET = '7.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

# Skip if already added
if project.targets.any? { |t| t.name == WATCH_NAME }
  puts "Target '#{WATCH_NAME}' already exists — skipping."
  exit 0
end

# ─── Source file references ────────────────────────────────────────────────
watch_group = project.main_group.new_group(WATCH_NAME, WATCH_NAME)

def add_file(group, rel_path)
  parts = rel_path.split('/')
  current = group
  parts[0..-2].each do |part|
    current = current[part] || current.new_group(part, part)
  end
  current.new_file(rel_path)
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

swift_refs   = swift_files.map { |f| add_file(watch_group, "#{WATCH_NAME}/#{f}") }
plist_ref    = add_file(watch_group, "#{WATCH_NAME}/Info.plist")
assets_ref   = add_file(watch_group, "#{WATCH_NAME}/Assets.xcassets")

# ─── Create watchOS application target ────────────────────────────────────
target = project.new_target(:application, WATCH_NAME, :watchos, DEPLOYMENT_TARGET)

# Source files
sources_phase = target.source_build_phase
swift_refs.each { |ref| sources_phase.add_file_reference(ref) }

# Resources
resources_phase = target.resources_build_phase
resources_phase.add_file_reference(plist_ref)
resources_phase.add_file_reference(assets_ref)

# ─── Build settings ────────────────────────────────────────────────────────
target.build_configurations.each do |config|
  s = config.build_settings
  s['SDKROOT']                         = 'watchos'
  s['TARGETED_DEVICE_FAMILY']          = '4'
  s['WATCHOS_DEPLOYMENT_TARGET']       = DEPLOYMENT_TARGET
  s['SWIFT_VERSION']                   = '5.0'
  s['PRODUCT_BUNDLE_IDENTIFIER']       = BUNDLE_ID
  s['DEVELOPMENT_TEAM']                = TEAM_ID
  s['INFOPLIST_FILE']                  = "#{WATCH_NAME}/Info.plist"
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['CODE_SIGN_STYLE']                 = 'Automatic'
  s['SKIP_INSTALL']                    = 'NO'
  s['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS']         = ['$(inherited)', '@executable_path/Frameworks']
  # watchOS does not support simulator code-signing
  s['CODE_SIGNING_ALLOWED[sdk=watchsimulator*]'] = 'NO'
  s['CODE_SIGNING_REQUIRED[sdk=watchsimulator*]'] = 'NO'
  s['EXPANDED_CODE_SIGN_IDENTITY[sdk=watchsimulator*]'] = ''
end

# ─── Add WatchBridge.swift to Runner ───────────────────────────────────────
runner = project.targets.find { |t| t.name == 'Runner' }
if runner
  runner.add_dependency(target)

  # Register WatchBridge.swift in the project file tree under Runner group
  runner_group = project.main_group['Runner'] ||
                 project.main_group.children.find { |g| g.respond_to?(:name) && g.name == 'Runner' }
  if runner_group
    bridge_ref = runner_group.new_file('Runner/WatchBridge.swift')
    runner.source_build_phase.add_file_reference(bridge_ref)
  end

  # Embed Watch Content build phase (dst_subfolder_spec 16 = Watch)
  embed_phase = runner.build_phases.find { |p|
    p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.dst_subfolder_spec == '16'
  }
  unless embed_phase
    embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed_phase.name = 'Embed Watch Content'
    embed_phase.dst_subfolder_spec = '16'
    embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
    runner.build_phases << embed_phase
  end
  watch_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  watch_build_file.file_ref = target.product_reference
  watch_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  embed_phase.files << watch_build_file

  # Enable WatchConnectivity framework for Runner if not already there
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

# WatchConnectivity framework for the watch target itself
watch_frameworks = target.frameworks_build_phase
wc_watch_ref = project.frameworks_group.new_file(
  'System/Library/Frameworks/WatchConnectivity.framework'
)
wc_watch_ref.source_tree = 'SDKROOT'
watch_frameworks.add_file_reference(wc_watch_ref)

project.save
puts "Done — '#{WATCH_NAME}' target added to #{PROJECT_PATH}"
