#!/usr/bin/env ruby
# Wires .build/ghostty/GhosttyKit.xcframework into the Stanok target.
# Idempotent: safe to re-run after regenerating the xcframework.
require 'xcodeproj'

root = File.expand_path('..', __dir__)
xcframework = '.build/ghostty/GhosttyKit.xcframework'

unless Dir.exist?(File.join(root, xcframework))
  abort "missing #{xcframework} — run scripts/build-ghostty.sh first"
end

project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

ref = project.files.find { |f| f.path == xcframework } || project.new_file(xcframework)
phase = target.frameworks_build_phase
phase.add_file_reference(ref) unless phase.files_references.include?(ref)

unless project.files.any? { |f| f.path.to_s.end_with?('Carbon.framework') }
  target.add_system_framework('Carbon')
end

target.build_configurations.each do |config|
  flags = Array(config.build_settings['OTHER_LDFLAGS'] || ['$(inherited)'])
  flags << '-lstdc++' unless flags.include?('-lstdc++')
  config.build_settings['OTHER_LDFLAGS'] = flags
end

project.save
puts "linked #{xcframework} into target Stanok"
