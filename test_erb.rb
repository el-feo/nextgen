#!/usr/bin/env ruby

require 'erb'
require 'active_support/all'

# Test ERB template rendering
@organization_name = "Organization"

template_path = File.expand_path('lib/nextgen/generators/multi_tenancy/tenant_scoped.rb.erb', __dir__)
template_content = File.read(template_path)

erb = ERB.new(template_content)
result = erb.result(binding)

# Check if result is valid Ruby
begin
  eval(result, binding, "tenant_scoped.rb")
  puts "✅ ERB template renders to valid Ruby"
rescue SyntaxError => e
  puts "❌ Rendered Ruby has syntax errors:"
  puts e.message
  puts "---"
  lines = result.split("\n")
  e.message.scan(/:\d+:/) do |match|
    line_num = match[1..-2].to_i - 1
    puts "Line #{line_num + 1}: #{lines[line_num]}" if lines[line_num]
  end
end
