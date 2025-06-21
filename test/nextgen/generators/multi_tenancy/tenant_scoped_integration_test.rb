# frozen_string_literal: true

require 'test_helper'

# Integration tests for TenantScoped concern behavior patterns
# This test suite verifies the structure and expected behavior patterns
class TenantScopedIntegrationTest < Minitest::Test
  def setup
    @template_path = File.join(
      File.dirname(__FILE__),
      '../../../../lib/nextgen/generators/multi_tenancy/tenant_scoped.rb.erb'
    )
    @organization_name = 'Organization'
    @template_content = File.read(@template_path)
  end

  def test_template_includes_all_required_model_integration_patterns
    # Test that the template includes patterns needed for model integration

    # Should include belongs_to association setup
    assert_match(/belongs_to :<%=.*organization_name.*%>/, @template_content)
    assert_match(/optional: false/, @template_content)

    # Should include validation setup
    assert_match(/validates :<%=.*organization_name.*%>_id, presence: true/, @template_content)

    # Should include default scope for automatic filtering
    assert_match(/default_scope -> {/, @template_content)
    assert_match(/current_<%=.*organization_name.*%>_id/, @template_content)

    # Should include callbacks for automatic organization assignment
    assert_match(/before_validation :set_current_<%=.*organization_name.*%>, on: :create/, @template_content)
    assert_match(/before_update :ensure_<%=.*organization_name.*%>_not_changed/, @template_content)

    # Should include model registration
    assert_match(/after_initialize/, @template_content)
    assert_match(/register_tenant_scoped_model/, @template_content)
  end

  def test_template_includes_comprehensive_bypass_methods
    # All bypass methods should be present
    bypass_methods = [
      'without_tenant_scoping',
      'with_admin_bypass',
      'with_organization_bypass',
      'for_each_organization',
      'without_tenant_scoping_readonly'
    ]

    bypass_methods.each do |method|
      assert_match(/def #{method}/, @template_content)

      # Each should have security checks
      method_content = extract_method_section(method)
      if method_content
        assert_match(/bypasses_disabled\?/, method_content)
        assert_match(/log_bypass_operation/, method_content)
      end
    end
  end

  def test_template_includes_thread_safety_patterns
    # Should use thread-safe storage
    assert_match(/Thread\.current\[:current_.*_id\]/, @template_content)
    assert_match(/RequestStore\.store/, @template_content)
    assert_match(/defined\?\(RequestStore\)/, @template_content)

    # Should restore context in ensure blocks
    assert_match(/ensure/, @template_content)
    assert_match(/previous_.*_id/, @template_content)

    # Should use bypass flags to prevent query monitoring false positives
    assert_match(/Thread\.current\[:tenant_scoping_bypass_active\]/, @template_content)
  end

  def test_template_includes_security_patterns
    # Production environment checks
    assert_match(/Rails\.env\.production\?/, @template_content)

    # Admin authorization patterns
    assert_match(/admin_check/, @template_content)
    assert_match(/admin_check\.call/, @template_content)
    assert_match(/AdminAuthorizationError/, @template_content)

    # Audit logging
    assert_match(/Rails\.logger\.warn/, @template_content)
    assert_match(/caller_location/, @template_content)

    # Cross-tenant access protection
    assert_match(/CrossTenantAccessError/, @template_content)
    assert_match(/Admin authorization required for cross-tenant access/, @template_content)
  end

  def test_template_includes_validation_compatibility_checks
    # Model compatibility validation
    assert_match(/validate_tenant_scoping_compatibility!/, @template_content)
    assert_match(/has_organization_column\?/, @template_content)
    assert_match(/column_names\.include\?/, @template_content)

    # SystemScoped integration
    assert_match(/SystemScoped::Configuration/, @template_content)
    assert_match(/excluded_model\?/, @template_content)
    assert_match(/system_scoped\?/, @template_content)

    # Error handling for missing columns
    assert_match(/MissingColumnError/, @template_content)
    assert_match(/IncompatibleModelError/, @template_content)
  end

  def test_template_includes_context_management_methods
    # Current organization getters/setters
    assert_match(/def self\.current_<%=.*organization_name.*%>_id/, @template_content)
    assert_match(/def self\.current_<%=.*organization_name.*%>_id=/, @template_content)
    assert_match(/def self\.current_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def self\.current_<%=.*organization_name.*%>=/, @template_content)

    # Context management blocks
    assert_match(/def self\.with_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def self\.without_<%=.*organization_name.*%>/, @template_content)

    # Context clearing
    assert_match(/def self\.clear_context!/, @template_content)
    assert_match(/context_storage_available\?/, @template_content)
  end

  def test_template_includes_introspection_methods
    # Scoping type identification
    assert_match(/def tenant_scoped\?/, @template_content)
    assert_match(/def system_scoped\?/, @template_content)
    assert_match(/def scoping_type/, @template_content)

    # Model registration and tracking
    assert_match(/def self\.tenant_scoped_models/, @template_content)
    assert_match(/def self\.register_tenant_scoped_model/, @template_content)
    assert_match(/def self\.model_tenant_scoped\?/, @template_content)

    # Summary and debugging
    assert_match(/def self\.scoping_summary/, @template_content)
    assert_match(/def self\.print_scoping_summary/, @template_content)
  end

  def test_template_includes_instance_methods
    # Organization membership checks
    assert_match(/def belongs_to_current_<%=.*organization_name.*%>\?/, @template_content)
    assert_match(/def can_be_accessed_by\?/, @template_content)

    # Private callback methods
    assert_match(/def set_current_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def ensure_<%=.*organization_name.*%>_not_changed/, @template_content)

    # Organization assignment logic
    assert_match(/return if <%=.*organization_name.*%>_id\.present\?/, @template_content)
    assert_match(/cannot be changed after creation/, @template_content)
    assert_match(/throw :abort/, @template_content)
  end

  def test_template_includes_error_recovery_patterns
    # Ensure blocks for context restoration
    ensure_count = @template_content.scan(/ensure/).length
    assert ensure_count >= 3, "Should have multiple ensure blocks for error recovery"

    # Exception handling
    assert_match(/rescue.*Error/, @template_content)
    assert_match(/begin/, @template_content)

    # Context restoration variables
    assert_match(/previous_.*_flag/, @template_content)
    assert_match(/previous_.*_id/, @template_content)
  end

  def test_template_includes_helpful_documentation
    # Usage examples
    assert_match(/USAGE EXAMPLES:/, @template_content)
    assert_match(/Basic bypass for data migrations:/, @template_content)
    assert_match(/Admin-authorized bypass:/, @template_content)

    # Configuration guidance
    assert_match(/CONFIGURATION EXAMPLES:/, @template_content)
    assert_match(/ERROR HANDLING EXAMPLES:/, @template_content)
    assert_match(/DEBUGGING TOOLS:/, @template_content)

    # Error resolution guidance
    assert_match(/To fix this issue, you have several options/, @template_content)
    assert_match(/rails generate migration/, @template_content)
    assert_match(/include SystemScoped/, @template_content)
  end

  def test_template_environment_specific_behavior
    # Development/test vs production differences
    development_patterns = [
      /Rails\.env\.production\?/,
      /if Rails\.env\.production\?/,
      /unless.*enabled/
    ]

    development_patterns.each do |pattern|
      assert_match(pattern, @template_content)
    end

    # Production-specific logging and warnings
    assert_match(/WARNING.*production/, @template_content)
    assert_match(/caller_location/, @template_content)

    # Test/development allowances
    assert_match(/In development\/test.*easier testing/, @template_content)
  end

  def test_template_includes_performance_considerations
    # Query optimization hints
    assert_match(/#\s*add_index table_name.*<%=.*organization_name/, @template_content)

    # Readonly relations for reporting
    assert_match(/readonly/, @template_content)
    assert_match(/without_tenant_scoping_readonly/, @template_content)

    # Efficient organization iteration
    assert_match(/find_each/, @template_content)

    # Model counting methods
    assert_match(/total_count_all_organizations/, @template_content)
  end

  def test_template_data_isolation_guarantees
    # Default scope ensures isolation
    assert_match(/default_scope/, @template_content)
    assert_match(/where\(<%=.*organization_name.*%>_id:/, @template_content)

    # Production safety - return empty on missing context
    assert_match(/none/, @template_content)
    assert_match(/prevent data leakage/, @template_content)

    # Organization validation prevents cross-tenant access
    assert_match(/validates :<%=.*organization_name.*%>_id, presence: true/, @template_content)
    assert_match(/cannot be changed after creation/, @template_content)
  end

  def test_template_compatibility_error_messages
    # Should provide helpful error messages for common issues
    error_guidance_patterns = [
      /To fix this issue/,
      /rails generate migration/,
      /Add.*missing column/,
      /include SystemScoped/,
      /exclude_model/
    ]

    error_guidance_patterns.each do |pattern|
      assert_match(pattern, @template_content)
    end
  end

  private

  def extract_method_section(method_name)
    # Extract a method's content for testing
    start_index = @template_content.index("def #{method_name}")
    return nil unless start_index

    # Find the end of the method
    lines = @template_content[start_index..-1].lines
    method_lines = []
    in_method = false
    indent_level = 0

    lines.each do |line|
      if line.strip.start_with?("def #{method_name}")
        in_method = true
        indent_level = line.index(/\S/) || 0
        method_lines << line
      elsif in_method
        current_indent = line.index(/\S/) || 0

        # End method if we hit 'end' at same level or another 'def'
        if (line.strip == 'end' && current_indent <= indent_level) ||
           (line.strip.start_with?('def ') && current_indent <= indent_level)
          method_lines << line if line.strip == 'end'
          break
        else
          method_lines << line
        end
      end
    end

    method_lines.join
  end
end
