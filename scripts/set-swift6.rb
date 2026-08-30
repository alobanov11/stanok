#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SWIFT_VERSION'] = '6.0'
    config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  end
end

project.save
puts 'SWIFT_VERSION=6.0, SWIFT_STRICT_CONCURRENCY=complete'
