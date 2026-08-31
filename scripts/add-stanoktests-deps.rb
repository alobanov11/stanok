#!/usr/bin/env ruby
gem 'xcodeproj', '>= 1.28'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'Stanok.xcodeproj'))
target = project.targets.find { |t| t.name == 'StanokTests' } or abort 'target StanokTests not found'

package_reference = project.root_object.package_references.find do |ref|
  ref.isa == 'XCLocalSwiftPackageReference' && ref.relative_path == 'StanokKit'
end or abort 'XCLocalSwiftPackageReference "StanokKit" not found'

%w[StanokKit StanokTerminal StanokAgents].each do |product_name|
  target.package_product_dependencies.delete_if { |dep| dep.product_name == product_name }

  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = product_name
  dependency.package = package_reference
  target.package_product_dependencies << dependency

  phase = target.frameworks_build_phase
  next if phase.files.any? { |f| f.product_ref == dependency }

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  phase.files << build_file
end

project.save
puts 'linked local package products StanokKit, StanokTerminal and StanokAgents into target StanokTests'
