#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

name = 'SwiftLint'
target.build_phases.delete_if { |p| p.respond_to?(:name) && p.name == name }

phase = target.new_shell_script_build_phase(name)
phase.shell_script = <<~SH
  # Xcode's script sandbox denies mise shims (they read mise.toml), so bypass PATH.
  for candidate in /opt/homebrew/bin/swiftlint /usr/local/bin/swiftlint; do
    if [ -x "$candidate" ]; then
      exec "$candidate" lint --quiet --force-exclude --use-alternative-excluding Stanok StanokKit/Sources StanokKit/Terminal
    fi
  done
  echo "warning: swiftlint not found — run: brew install swiftlint"
SH
phase.always_out_of_date = '1'
target.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end
target.build_phases.delete(phase)
target.build_phases.unshift(phase)

project.save
puts "added #{name} build phase to target Stanok"
