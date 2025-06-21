# frozen_string_literal: true

require_relative "test/test_helper"

puts "Loading MultiTenancyGenerator..."
generator = MultiTenancyGenerator.new
puts "Generator loaded successfully!"
puts "Generator class: #{generator.class}"
puts "Generator responds to execute: #{generator.respond_to?(:execute)}"
