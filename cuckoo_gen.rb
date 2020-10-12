#!/usr/bin/ruby
require 'rubygems'
require 'xcodeproj'
require 'optparse'

xcodeproj_path = nil
target_name = nil

OptionParser.new do |parser|
    parser.on("-p", "--project=PROJECT", "Path to the project's .xcodeproj file.") do |project|
        xcodeproj_path = Pathname.new(project)
    end
    parser.on("-t", "--target=TARGET", "Name of the target to generate mocks for.") do |target|
        target_name = target
    end
end.parse!

if xcodeproj_path.nil? 
    abort("Missing project .xcodeproj location. Use '#{__FILE__} --help|-h' to print usage.")
end

proj = Xcodeproj::Project.open(xcodeproj_path)

if target_name.nil?
    abort("Missing target name to generate mocks for. Use '#{$PROGRAM_NAME} --help|-h' to print usage.\n\nAvailable targets: #{data.targets.map { |t| t.name }}")
end

target = proj.targets.select {|target| target.name == target_name}.first

project_path = xcodeproj_path.parent
output_file_name = "GeneratedMocks.swift"
output_file_path = Pathname.new("#{project_path}/#{target_name}/#{output_file_name}")

cuckoo_command = "\"#{project_path}/Carthage/Checkouts/Cuckoo/run\" generate --output \"#{output_file_path}\" --no-header"

target.source_build_phase.files.each do |source|
    source_file_path = source.file_ref.real_path
    if source_file_path.to_s.end_with? output_file_name
        next
    end
    source_file_contents = File.read(source_file_path)
    if !source_file_path.to_s.include? "/#{target_name}/"
        relative_path = Pathname.new(source_file_path).relative_path_from(__dir__)
        cuckoo_command += " \\\n\"#{relative_path}\""
    end
end

unless output_file_path.exist?
    puts("GeneratedMocks.swift does not exist, adding to #{target_name} target...")
    group = proj.main_group[target_name]
    file = group.new_file("GeneratedMocks.swift")
    target.add_file_references([file])
    proj.save
end

puts "Generating mocks in #{output_file_path}..."

if system(cuckoo_command)
    puts "Mocks generated successfully!"
else
    puts "Unexpected error while generating mocks."
end

# Next steps: Filter files that are named "Stub" or "Mock" to avoid clashes/duplicated methods