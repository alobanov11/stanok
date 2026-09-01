#!/usr/bin/env ruby
require "xcodeproj"

project = Xcodeproj::Project.open("Stanok.xcodeproj")
target = project.targets.find { |candidate| candidate.name == "Stanok" }
abort "нет таргета Stanok" unless target

target.build_configurations.each do |config|
  config.build_settings["ENABLE_DEBUG_DYLIB"] = "NO"
end

project.save
puts "ENABLE_DEBUG_DYLIB=NO для #{target.build_configurations.map(&:name).join(", ")}"
