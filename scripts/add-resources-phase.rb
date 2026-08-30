#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

name = 'Ghostty Resources'
target.build_phases.delete_if { |p| p.respond_to?(:name) && p.name == name }

phase = target.new_shell_script_build_phase(name)
phase.shell_script = <<~SH
  # Without these ghostty falls back to xterm-256color and disables shell integration.
  share="$SRCROOT/.build/ghostty/share"
  dest="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources"
  if [ ! -d "$share/ghostty" ]; then
    echo "warning: $share/ghostty missing — run scripts/build-ghostty.sh"
    exit 0
  fi
  mkdir -p "$dest"
  rsync -a --delete "$share/ghostty/" "$dest/ghostty/"
  rsync -a --delete "$share/terminfo/" "$dest/terminfo/"
SH
phase.always_out_of_date = '1'

project.save
puts "added #{name} build phase to target Stanok"
