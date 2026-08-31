#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

name = 'Format & Lint'
stale = [name, 'Project Rules', 'File Groups', 'SwiftLint']
target.build_phases.delete_if { |p| p.respond_to?(:name) && stale.include?(p.name) }
project.objects
       .select { |o| o.isa == 'PBXShellScriptBuildPhase' && stale.include?(o.name) }
       .each(&:remove_from_project)

phase = target.new_shell_script_build_phase(name)
phase.shell_script = <<~SH
  cd "$SRCROOT" || exit 0
  /usr/bin/make format || exit 1
  exec /usr/bin/make lint
SH
phase.always_out_of_date = '1'
target.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end
target.build_phases.delete(phase)
target.build_phases.unshift(phase)

project.save
puts "added #{name} build phase to target Stanok"
