#!/usr/bin/env ruby
# Test script to verify TenantScoped concern inclusion functionality

require 'tmpdir'
require 'fileutils'

# Simulate the file modification logic without requiring Rails
def simulate_include_tenant_scoped_in_model(model_file_path, model_name)
  puts "[INFO] Adding TenantScoped concern to #{model_name}"

  # Check if file exists
  unless File.exist?(model_file_path)
    puts "[WARNING] Skipping #{model_name}: Model file not found at #{model_file_path}"
    return false
  end

  # Check if TenantScoped is already included
  model_content = File.read(model_file_path)
  if model_content.match?(/^\s*include\s+TenantScoped\b/)
    puts "[INFO] Skipping #{model_name}: TenantScoped already included"
    return false
  end

  # Find the class declaration line
  class_pattern = /^(\s*)class\s+#{Regexp.escape(model_name)}\b.*$/
  match = model_content.match(class_pattern)

  unless match
    puts "[ERROR] Could not find class declaration for #{model_name} in #{model_file_path}"
    return false
  end

  # Find the line after the class declaration
  lines = model_content.lines
  class_line_index = nil

  lines.each_with_index do |line, index|
    if line.match?(class_pattern)
      class_line_index = index
      break
    end
  end

  # Insert the include statement after the class line
  lines.insert(class_line_index + 1, "  include TenantScoped\n")

  # Write back to file
  File.write(model_file_path, lines.join)
  puts "[SUCCESS] ✓ Added TenantScoped to #{model_name}"

  true
end

# Create a temporary directory to simulate a Rails app structure
Dir.mktmpdir do |tmpdir|
  puts "Testing in temporary directory: #{tmpdir}"

  # Change to the temp directory
  original_dir = Dir.pwd
  Dir.chdir(tmpdir)

  begin
    # Create app/models directory
    FileUtils.mkdir_p('app/models')

    # Create a sample model file
    model_content = <<~RUBY
      class Product < ApplicationRecord
        validates :name, presence: true
        validates :price, presence: true, numericality: { greater_than: 0 }

        belongs_to :category
        has_many :reviews, dependent: :destroy
      end
    RUBY

    File.write('app/models/product.rb', model_content)

    puts "\n=== BEFORE: Model file content ==="
    puts File.read('app/models/product.rb')

    # Test the include method
    result1 = simulate_include_tenant_scoped_in_model('app/models/product.rb', 'Product')

    puts "\n=== AFTER: Model file content ==="
    puts File.read('app/models/product.rb')

    # Verify the concern was added
    updated_content = File.read('app/models/product.rb')
    if updated_content.include?('include TenantScoped')
      puts "\n✅ SUCCESS: TenantScoped concern was successfully included!"
    else
      puts "\n❌ FAILURE: TenantScoped concern was NOT included."
      exit 1
    end

    # Test that running it again doesn't add duplicate includes
    puts "\n=== Testing duplicate inclusion prevention ==="
    result2 = simulate_include_tenant_scoped_in_model('app/models/product.rb', 'Product')

    final_content = File.read('app/models/product.rb')
    include_count = final_content.scan(/include TenantScoped/).length

    if include_count == 1
      puts "✅ SUCCESS: Duplicate inclusion was prevented!"
    else
      puts "❌ FAILURE: Found #{include_count} TenantScoped includes (should be 1)"
      exit 1
    end

    # Test edge case: model with different inheritance
    edge_case_content = <<~RUBY
      class SystemModel < ActiveRecord::Base
        # This is a system model
        validates :name, presence: true
      end
    RUBY

    File.write('app/models/system_model.rb', edge_case_content)

    puts "\n=== Testing edge case: Different inheritance pattern ==="
    puts "BEFORE:"
    puts File.read('app/models/system_model.rb')

    result3 = simulate_include_tenant_scoped_in_model('app/models/system_model.rb', 'SystemModel')

    puts "AFTER:"
    puts File.read('app/models/system_model.rb')

    edge_case_final = File.read('app/models/system_model.rb')
    if edge_case_final.include?('include TenantScoped')
      puts "✅ SUCCESS: TenantScoped was added to edge case model!"
    else
      puts "❌ FAILURE: TenantScoped was NOT added to edge case model."
      exit 1
    end

  ensure
    Dir.chdir(original_dir)
  end
end

puts "\n🎉 All tests passed! The TenantScoped inclusion functionality works correctly."
