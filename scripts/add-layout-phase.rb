#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

name = 'Project Rules'
stale = [name, 'File Groups']
target.build_phases.delete_if { |p| p.respond_to?(:name) && stale.include?(p.name) }

phase = target.new_shell_script_build_phase(name)
phase.shell_script = <<~SH
  cd "$SRCROOT" || exit 0
  /usr/bin/python3 scripts/check-file-groups.py || exit 1
  exec /usr/bin/python3 scripts/check-declaration-order.py
SH
phase.always_out_of_date = '1'
target.build_phases.delete(phase)
target.build_phases.unshift(phase)

project.save
puts "added #{name} build phase to target Stanok"
