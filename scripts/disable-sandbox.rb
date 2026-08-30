#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

target.build_configurations.each do |config|
  config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
end

project.save
puts 'ENABLE_APP_SANDBOX=NO (a terminal cannot exec /usr/bin/login inside the sandbox)'
