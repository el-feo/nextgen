#!/usr/bin/env ruby

# Test script for data migration guidance generation
puts "Testing Data Migration Guidance Generation"
puts "=" * 50

# Simulate the models data that would be available
models_needing_org_id = [
  { name: 'Post', model: nil },
  { name: 'Comment', model: nil },
  { name: 'Tag', model: nil }
]

models_already_compatible = [
  { name: 'Image', model: nil }
]

org_name = 'organization'
org_class = 'Organization'
tenant_column = 'organization_id'

# Test building the assignment code
def build_model_assignment_code(models_with_data, org_name, tenant_column, indent)
  models_with_data.map do |model_info|
    model_name = model_info[:name]
    <<~RUBY.gsub(/^/, indent)
      # Assign #{model_name} records
      #{model_name}.where(#{tenant_column}: nil).find_each do |record|
        record.update!(#{tenant_column}: default_org.id)
      end
      puts "Assigned \#{#{model_name}.where(#{tenant_column}: default_org.id).count} #{model_name.underscore.pluralize}"
    RUBY
  end.join("\n")
end

puts "Sample assignment code:"
puts build_model_assignment_code(models_needing_org_id + models_already_compatible, org_name, tenant_column, '    ')

puts "\nTest completed successfully!"
