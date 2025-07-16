#!/usr/bin/env ruby

# Test script for association updating logic
puts "Testing Association Updating Logic"
puts "=" * 50

# Test the regex patterns used in the generator
test_model_content = <<~RUBY
  class Post < ApplicationRecord
    belongs_to :user
    has_many :comments
    has_many :tags, through: :post_tags
    has_one :featured_image, -> { where(featured: true) }, class_name: 'Image'
    has_many :likes

    validates :title, presence: true
  end
RUBY

puts "Test Model Content:"
puts test_model_content
puts

# Test has_many pattern
puts "Testing has_many pattern:"
test_model_content.scan(/^\s*(has_many\s+:(\w+)(?:,\s*(.*))?)\s*$/) do |full_match, assoc_name, options|
  puts "  Found: #{full_match}"
  puts "    Association: #{assoc_name}"
  puts "    Options: #{options || 'none'}"
  puts "    Already scoped: #{full_match.include?('->') || full_match.include?('lambda')}"
  puts
end

# Test has_one pattern
puts "Testing has_one pattern:"
test_model_content.scan(/^\s*(has_one\s+:(\w+)(?:,\s*(.*))?)\s*$/) do |full_match, assoc_name, options|
  puts "  Found: #{full_match}"
  puts "    Association: #{assoc_name}"
  puts "    Options: #{options || 'none'}"
  puts "    Already scoped: #{full_match.include?('->') || full_match.include?('lambda')}"
  puts
end

# Test belongs_to pattern
puts "Testing belongs_to pattern:"
test_model_content.scan(/^\s*(belongs_to\s+:(\w+)(?:,\s*(.*))?)\s*$/) do |full_match, assoc_name, options|
  puts "  Found: #{full_match}"
  puts "    Association: #{assoc_name}"
  puts "    Options: #{options || 'none'}"
  puts "    Already scoped: #{full_match.include?('->') || full_match.include?('lambda')}"
  puts
end

# Test string replacement
puts "Testing string replacement for scoped association:"
original_line = "has_many :comments"
scope_lambda = "-> { where(organization_id: current_organization_id) }"
comment = "  # Tenant-scoped association: only returns comments within the current organization"
scoped_association = "has_many :comments, #{scope_lambda}"
scoped_with_comment = "#{comment}\n  #{scoped_association}"

puts "Original: #{original_line}"
puts "Replacement:"
puts scoped_with_comment
puts

# Test the actual replacement
result = test_model_content.gsub(/^\s*#{Regexp.escape(original_line)}.*$/, scoped_with_comment)
puts "Result after replacement:"
puts result

puts "\nTest completed!"
