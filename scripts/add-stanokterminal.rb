#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

target.package_product_dependencies.delete_if { |dep| dep.product_name == 'StanokTerminal' }

package_reference = project.root_object.package_references.find do |ref|
  ref.isa == 'XCLocalSwiftPackageReference' && ref.relative_path == 'StanokKit'
end or abort 'XCLocalSwiftPackageReference "StanokKit" not found'

dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dependency.product_name = 'StanokTerminal'
dependency.package = package_reference
target.package_product_dependencies << dependency

phase = target.frameworks_build_phase
unless phase.files.any? { |f| f.product_ref == dependency }
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  phase.files << build_file
end

xcframework_ref = project.files.find { |f| f.path == '.build/ghostty/GhosttyKit.xcframework' }
if xcframework_ref
  phase.remove_file_reference(xcframework_ref)
  xcframework_ref.remove_from_project
  puts 'removed direct GhosttyKit.xcframework link from target Stanok'
end

project.save
puts 'linked local package product StanokTerminal into target Stanok'
