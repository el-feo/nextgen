# frozen_string_literal: true

require 'test_helper'

# Test suite for TenantScoped concern functionality
# This test verifies all functionality in the generated TenantScoped concern template
class TenantScopedTest < Minitest::Test
  def setup
    @template_path = File.join(
      File.dirname(__FILE__),
      '../../../../lib/nextgen/generators/multi_tenancy/tenant_scoped.rb.erb'
    )
    @template_content = File.read(@template_path)
    @organization_name = 'Organization'
  end

  def test_template_file_exists
    assert File.exist?(@template_path), "TenantScoped template should exist"
  end

  def test_template_is_valid_erb
    erb = ERB.new(@template_content)
    assert erb, "ERB template should be valid"

    # Test that it can be rendered without syntax errors
    rendered = erb.result(binding)
    assert rendered.length > 0, "ERB template should render content"
  end

  def test_template_contains_module_definition
    assert_match(/module TenantScoped/, @template_content)
    assert_match(/extend ActiveSupport::Concern/, @template_content)
  end

  def test_template_contains_error_classes
    assert_match(/class TenantScopingError < SecurityError/, @template_content)
    assert_match(/class AdminAuthorizationError < TenantScopingError/, @template_content)
    assert_match(/class CrossTenantAccessError < TenantScopingError/, @template_content)
    assert_match(/class UnscopedQueryError < TenantScopingError/, @template_content)
  end

  def test_template_contains_bypass_configuration
    assert_match(/BYPASS_AUDIT_LOG_LEVEL = :warn/, @template_content)
    assert_match(/BYPASS_ENABLED_ENVIRONMENTS/, @template_content)
  end

  def test_template_contains_included_block
    assert_match(/included do/, @template_content)
    assert_match(/validate_tenant_scoping_compatibility!/, @template_content)
    assert_match(/belongs_to :<%=.*organization_name.*%>/, @template_content)
    assert_match(/validates :<%=.*organization_name.*%>_id, presence: true/, @template_content)
  end

  def test_template_contains_default_scope
    assert_match(/default_scope -> {/, @template_content)
    assert_match(/current_<%=.*organization_name.*%>_id/, @template_content)
    assert_match(/where\(<%=.*organization_name.*%>_id:/, @template_content)
    assert_match(/if Rails\.env\.production\?/, @template_content)
    assert_match(/none/, @template_content)
    assert_match(/else/, @template_content)
    assert_match(/all/, @template_content)
  end

  def test_template_contains_callbacks
    assert_match(/before_validation :set_current_<%=.*organization_name.*%>, on: :create/, @template_content)
    assert_match(/before_update :ensure_<%=.*organization_name.*%>_not_changed/, @template_content)
    assert_match(/after_initialize/, @template_content)
  end

  def test_template_contains_class_methods_module
    assert_match(/module ClassMethods/, @template_content)
  end

  def test_template_contains_bypass_methods
    assert_match(/def without_tenant_scoping/, @template_content)
    assert_match(/def with_admin_bypass/, @template_content)
    assert_match(/def with_organization_bypass/, @template_content)
    assert_match(/def for_each_organization/, @template_content)
    assert_match(/def without_tenant_scoping_readonly/, @template_content)
  end

  def test_template_contains_introspection_methods
    assert_match(/def tenant_scoping_active\?/, @template_content)
    assert_match(/def current_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def tenant_scoped\?/, @template_content)
    assert_match(/def system_scoped\?/, @template_content)
    assert_match(/def scoping_type/, @template_content)
  end

  def test_template_contains_validation_methods
    assert_match(/def validate_tenant_scoping_compatibility!/, @template_content)
    assert_match(/def has_organization_column\?/, @template_content)
  end

  def test_template_contains_admin_methods
    assert_match(/def all_organizations_unscoped/, @template_content)
    assert_match(/def total_count_all_organizations/, @template_content)
  end

  def test_template_contains_module_level_methods
    assert_match(/def self\.current_<%=.*organization_name.*%>_id/, @template_content)
    assert_match(/def self\.current_<%=.*organization_name.*%>_id=/, @template_content)
    assert_match(/def self\.context_storage_available\?/, @template_content)
    assert_match(/def self\.clear_context!/, @template_content)
    assert_match(/def self\.current_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def self\.current_<%=.*organization_name.*%>=/, @template_content)
  end

  def test_template_contains_context_management_methods
    assert_match(/def self\.with_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def self\.without_<%=.*organization_name.*%>/, @template_content)
  end

  def test_template_contains_instance_methods
    assert_match(/def belongs_to_current_<%=.*organization_name.*%>\?/, @template_content)
    assert_match(/def can_be_accessed_by\?/, @template_content)
  end

  def test_template_contains_private_methods
    assert_match(/private/, @template_content)
    assert_match(/def set_current_<%=.*organization_name.*%>/, @template_content)
    assert_match(/def ensure_<%=.*organization_name.*%>_not_changed/, @template_content)
  end

  def test_template_contains_validation_logic
    assert_match(/def self\.validate_tenant_scoping_compatibility!/, @template_content)
    assert_match(/def self\.included/, @template_content)
    assert_match(/SystemScoped::Configuration\.validate_tenant_scoping_compatibility!/, @template_content)
  end

  def test_template_contains_error_handling
    assert_match(/class ModelIncompatibilityError < TenantScopingError/, @template_content)
    assert_match(/class MissingColumnError < TenantScopingError/, @template_content)
    assert_match(/rescue SystemScoped::Configuration::IncompatibleModelError/, @template_content)
    assert_match(/rescue SystemScoped::Configuration::MissingColumnError/, @template_content)
  end

  def test_template_contains_helper_methods
    assert_match(/def self\.model_compatible\?/, @template_content)
    assert_match(/def self\.tenant_scoped_models/, @template_content)
    assert_match(/def self\.register_tenant_scoped_model/, @template_content)
    assert_match(/def self\.model_tenant_scoped\?/, @template_content)
  end

  def test_template_contains_summary_methods
    assert_match(/def self\.scoping_summary/, @template_content)
    assert_match(/def self\.print_scoping_summary/, @template_content)
  end

  def test_template_contains_security_features
    # Bypass protection
    assert_match(/TenantScoped\.bypasses_disabled\?/, @template_content)
    assert_match(/TenantScoped\.bypass_enabled\?/, @template_content)

    # Admin authorization checks
    assert_match(/admin_check\.call/, @template_content)
    assert_match(/AdminAuthorizationError/, @template_content)
    assert_match(/CrossTenantAccessError/, @template_content)

    # Audit logging
    assert_match(/TenantScoped\.log_bypass_operation/, @template_content)
    assert_match(/Rails\.logger\.warn/, @template_content)

    # Production safeguards
    assert_match(/if Rails\.env\.production\?/, @template_content)
    assert_match(/caller_location = caller/, @template_content)
  end

  def test_template_contains_thread_safety_features
    assert_match(/Thread\.current\[:tenant_scoping_bypass_active\]/, @template_content)
    assert_match(/Thread\.current\[:current_<%=.*organization_name.*%>_id\]/, @template_content)
    assert_match(/RequestStore\.store/, @template_content)
    assert_match(/defined\?\(RequestStore\)/, @template_content)
  end

  def test_template_contains_organization_scoping_methods
    assert_match(/def for_<%=.*organization_name.*%>/, @template_content)
    assert_match(/unscoped\.where\(<%=.*organization_name.*%>_id:/, @template_content)
  end

  def test_template_contains_environment_handling
    assert_match(/unless TenantScoped\.bypass_enabled\?/, @template_content)
    assert_match(/BYPASS_ENABLED_ENVIRONMENTS/, @template_content)
    assert_match(/Rails\.env\.production\?/, @template_content)
  end

  def test_template_contains_logging_and_monitoring
    assert_match(/Rails\.logger\.warn/, @template_content)
    assert_match(/Rails\.logger\.error/, @template_content)
    assert_match(/Rails\.logger\.debug/, @template_content)
    assert_match(/Rails\.logger\.info/, @template_content)
    assert_match(/\[TENANT_WARNING\]/, @template_content)
    assert_match(/\[TENANT_ERROR\]/, @template_content)
    assert_match(/\[MULTI_TENANT\]/, @template_content)
    assert_match(/\[TENANT_REPORTING\]/, @template_content)
  end

  def test_template_contains_guidance_text
    assert_match(/To fix this issue, you have several options/, @template_content)
    assert_match(/rails generate migration/, @template_content)
    assert_match(/include SystemScoped/, @template_content)
    assert_match(/SystemScoped::Configuration\.exclude_model/, @template_content)
  end

  def test_template_contains_documentation_examples
    # Usage examples in comments
    assert_match(/USAGE EXAMPLES:/, @template_content)
    assert_match(/Basic bypass for data migrations:/, @template_content)
    assert_match(/Admin-authorized bypass:/, @template_content)
    assert_match(/Cross-tenant admin operations:/, @template_content)
    assert_match(/Multi-tenant data migrations:/, @template_content)
    assert_match(/Read-only bypass for reports:/, @template_content)

    # System model examples
    assert_match(/SYSTEM MODELS THAT SHOULD USE SystemScoped/, @template_content)
    assert_match(/Configuration Models:/, @template_content)
    assert_match(/Audit\/Logging Models:/, @template_content)
    assert_match(/Reference Data Models:/, @template_content)

    # Configuration examples
    assert_match(/CONFIGURATION EXAMPLES:/, @template_content)
    assert_match(/config\/initializers\/tenant_scoping\.rb/, @template_content)

    # Error handling examples
    assert_match(/ERROR HANDLING EXAMPLES:/, @template_content)
    assert_match(/Model missing organization_id column/, @template_content)

    # Debugging examples
    assert_match(/DEBUGGING TOOLS:/, @template_content)
    assert_match(/TenantScoped\.print_scoping_summary/, @template_content)
  end

  def test_template_renders_with_organization_variable
    rendered = ERB.new(@template_content).result(binding)

    # Check that ERB variables are properly replaced
    assert_match(/belongs_to :organization/, rendered)
    assert_match(/validates :organization_id/, rendered)
    assert_match(/current_organization_id/, rendered)
    assert_match(/def current_organization/, rendered)
    assert_match(/def set_current_organization/, rendered)
    assert_match(/def ensure_organization_not_changed/, rendered)

    # Ensure no ERB syntax remains
    refute_match(/<%=/, rendered)
    refute_match(/%>/, rendered)
  end

  def test_template_contains_proper_error_recovery
    assert_match(/ensure/, @template_content)
    assert_match(/previous_.*_flag/, @template_content)
    assert_match(/previous_.*_id/, @template_content)
    assert_match(/Thread\.current\[.*\] = previous/, @template_content)
  end

  def test_template_contains_readonly_protection
    assert_match(/readonly/, @template_content)
    assert_match(/respond_to\?\(:readonly\)/, @template_content)
    assert_match(/without_tenant_scoping_readonly/, @template_content)
  end

  def test_template_contains_validation_error_handling
    assert_match(/errors\.add/, @template_content)
    assert_match(/throw :abort/, @template_content)
    assert_match(/cannot be changed after creation/, @template_content)
  end

  def test_template_contains_compatibility_checks
    assert_match(/respond_to\?\(:column_names\)/, @template_content)
    assert_match(/column_names\.include\?/, @template_content)
    assert_match(/SystemScoped::Configuration\.excluded_model\?/, @template_content)
    assert_match(/respond_to\?\(:system_scoped\?\)/, @template_content)
  end

  def test_template_contains_model_registration
    assert_match(/@tenant_scoped_models/, @template_content)
    assert_match(/register_tenant_scoped_model/, @template_content)
    assert_match(/tenant_scoped_models << model_class/, @template_content)
    assert_match(/unless tenant_scoped_models\.include\?/, @template_content)
  end

  def test_template_contains_rails_integration
    assert_match(/Rails\.application/, @template_content)
    assert_match(/Rails\.application\.config\.after_initialize/, @template_content)
    assert_match(/defined\?\(Rails\)/, @template_content)
    assert_match(/ApplicationRecord\.descendants/, @template_content)
  end

  def test_template_security_measures
    # Test for security-related patterns
    security_patterns = [
      # Authorization checks
      /admin_check.*call/,
      /AdminAuthorizationError/,
      /Admin authorization required/,

      # Bypass protection
      /bypasses_disabled\?/,
      /bypass_enabled\?/,
      /Tenant scoping bypasses are globally disabled/,

      # Production warnings
      /Rails\.env\.production\?/,
      /WARNING.*production/,
      /caller_location/,

      # Data isolation
      /CrossTenantAccessError/,
      /cannot be changed after creation/,
      /none/ # Empty relation in production
    ]

    security_patterns.each do |pattern|
      assert_match(pattern, @template_content, "Security pattern #{pattern} not found")
    end
  end

  def test_template_error_guidance_completeness
    # Check that error messages provide helpful guidance
    guidance_patterns = [
      /To fix this issue/,
      /rails generate migration/,
      /include SystemScoped/,
      /exclude_model/,
      /Add.*missing column/,
      /system model.*exclusion list/
    ]

    guidance_patterns.each do |pattern|
      assert_match(pattern, @template_content, "Guidance pattern #{pattern} not found")
    end
  end

  def test_template_bypass_method_completeness
    # Each bypass method should have proper structure
    bypass_methods = %w[
      without_tenant_scoping
      with_admin_bypass
      with_organization_bypass
      for_each_organization
      without_tenant_scoping_readonly
    ]

    bypass_methods.each do |method|
      assert_match(/def #{method}/, @template_content)
      # Each should check if bypasses are disabled
      method_content = extract_method_content(method)
      assert_match(/bypasses_disabled\?/, method_content) if method_content
    end
  end

  def test_template_thread_safety_completeness
    thread_safety_patterns = [
      /Thread\.current\[:tenant_scoping_bypass_active\]/,
      /Thread\.current\[:current_.*_id\]/,
      /RequestStore\.store/,
      /previous_.*_flag/,
      /previous_.*_id/
    ]

    thread_safety_patterns.each do |pattern|
      assert_match(pattern, @template_content, "Thread safety pattern #{pattern} not found")
    end
  end

  private

  def extract_method_content(method_name)
    # Simple extraction of method content for testing
    # This is a basic implementation - could be more sophisticated
    method_start = @template_content.index("def #{method_name}")
    return nil unless method_start

    # Find the end of the method (next 'def' or 'end' at same indentation level)
    lines = @template_content[method_start..-1].lines
    method_lines = []
    indent_level = 0
    found_method_def = false

    lines.each do |line|
      if line.strip.start_with?('def ') && !found_method_def
        found_method_def = true
        method_lines << line
        indent_level = line.index(/\S/) || 0
      elsif found_method_def
        current_indent = line.index(/\S/) || 0

        # End method if we hit another def or end at same level
        if (line.strip.start_with?('def ') || line.strip == 'end') && current_indent <= indent_level
          break if line.strip.start_with?('def ')
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
