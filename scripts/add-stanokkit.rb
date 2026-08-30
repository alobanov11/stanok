#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'Stanok' } or abort 'target Stanok not found'

project.root_object.package_references.delete_if do |ref|
  ref.isa == 'XCLocalSwiftPackageReference' && ref.relative_path == 'StanokKit'
end
target.package_product_dependencies.delete_if { |dep| dep.product_name == 'StanokKit' }

reference = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
reference.relative_path = 'StanokKit'
project.root_object.package_references << reference

dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dependency.product_name = 'StanokKit'
target.package_product_dependencies << dependency

phase = target.frameworks_build_phase
unless phase.files.any? { |f| f.product_ref == dependency }
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  phase.files << build_file
end

project.save
puts 'linked local package StanokKit into target Stanok'
