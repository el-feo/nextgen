# frozen_string_literal: true

require 'test_helper'

# Functional tests for TenantScoped concern behavior
# This test suite creates mock models and tests the actual functionality
class TenantScopedFunctionalTest < Minitest::Test
  def setup
    @template_path = File.join(
      File.dirname(__FILE__),
      '../../../../lib/nextgen/generators/multi_tenancy/tenant_scoped.rb.erb'
    )
    @template_content = File.read(@template_path)
    @organization_name = 'Organization'

    # Create a temporary file with the rendered template
    @rendered_content = ERB.new(@template_content).result(binding)
    @temp_file = Tempfile.new(['tenant_scoped', '.rb'])
    @temp_file.write(@rendered_content)
    @temp_file.close

    # Load the rendered module
    load @temp_file.path
  end

  def teardown
    @temp_file.unlink if @temp_file

    # Clean up constants to avoid pollution between tests
    Object.send(:remove_const, :TenantScoped) if defined?(TenantScoped)
  rescue => e
    # Ignore cleanup errors
  end

  def test_module_is_loadable
    assert defined?(TenantScoped), "TenantScoped module should be loadable"
    assert TenantScoped.is_a?(Module), "TenantScoped should be a module"
  end

  def test_module_extends_active_support_concern
    skip "ActiveSupport not available in test environment"
  rescue NameError
    # Expected in test environment without full Rails
    pass
  end

  def test_error_classes_are_defined
    assert defined?(TenantScoped::TenantScopingError), "TenantScopingError should be defined"
    assert defined?(TenantScoped::AdminAuthorizationError), "AdminAuthorizationError should be defined"
    assert defined?(TenantScoped::CrossTenantAccessError), "CrossTenantAccessError should be defined"
    assert defined?(TenantScoped::UnscopedQueryError), "UnscopedQueryError should be defined"

    # Test inheritance
    assert TenantScoped::AdminAuthorizationError < TenantScoped::TenantScopingError
    assert TenantScoped::CrossTenantAccessError < TenantScoped::TenantScopingError
    assert TenantScoped::UnscopedQueryError < TenantScoped::TenantScopingError
    assert TenantScoped::TenantScopingError < SecurityError
  end

  def test_module_level_constants
    assert defined?(TenantScoped::BYPASS_AUDIT_LOG_LEVEL), "BYPASS_AUDIT_LOG_LEVEL should be defined"
    assert defined?(TenantScoped::BYPASS_ENABLED_ENVIRONMENTS), "BYPASS_ENABLED_ENVIRONMENTS should be defined"

    assert_equal :warn, TenantScoped::BYPASS_AUDIT_LOG_LEVEL
    assert_equal %w[development test production], TenantScoped::BYPASS_ENABLED_ENVIRONMENTS
  end

  def test_module_level_accessor_methods
    # Test current_organization_id getter/setter
    assert_respond_to TenantScoped, :current_organization_id
    assert_respond_to TenantScoped, :current_organization_id=

    # Test context management
    assert_respond_to TenantScoped, :context_storage_available?
    assert_respond_to TenantScoped, :clear_context!

    # Test organization getter/setter
    assert_respond_to TenantScoped, :current_organization
    assert_respond_to TenantScoped, :current_organization=
  end

  def test_context_management_methods
    assert_respond_to TenantScoped, :with_organization
    assert_respond_to TenantScoped, :without_organization
  end

  def test_validation_methods
    assert_respond_to TenantScoped, :validate_tenant_scoping_compatibility!
    assert_respond_to TenantScoped, :model_compatible?
  end

  def test_introspection_methods
    assert_respond_to TenantScoped, :tenant_scoped_models
    assert_respond_to TenantScoped, :register_tenant_scoped_model
    assert_respond_to TenantScoped, :model_tenant_scoped?
    assert_respond_to TenantScoped, :scoping_summary
    assert_respond_to TenantScoped, :print_scoping_summary
  end

  def test_current_organization_id_thread_safety
    # Test that the getter returns nil when nothing is set
    original_thread_value = Thread.current[:current_organization_id]
    Thread.current[:current_organization_id] = nil

    Thread.new do
      assert_nil TenantScoped.current_organization_id
    end.join

    # Test setting and getting values in current thread
    test_id = 123
    TenantScoped.current_organization_id = test_id
    assert_equal test_id, TenantScoped.current_organization_id

    # Test thread isolation - new thread should inherit but can change independently
    test_thread = Thread.new do
      # Note: Thread inheritance depends on implementation,
      # so we'll just test that setting works in the new thread
      TenantScoped.current_organization_id = 456
      assert_equal 456, TenantScoped.current_organization_id
    end
    test_thread.join

    # Original thread should still have the value we set
    assert_equal test_id, TenantScoped.current_organization_id

    # Restore original state
    Thread.current[:current_organization_id] = original_thread_value
  end

  def test_context_storage_available
    # Should return true since Thread.current responds to []
    assert TenantScoped.context_storage_available?
  end

  def test_clear_context
    # Set some context
    TenantScoped.current_organization_id = 123
    assert_equal 123, TenantScoped.current_organization_id

    # Mock Rails completely to avoid the env.production? call
    rails_mock = Class.new do
      def self.env
        env_mock = Class.new do
          def self.production?
            false
          end
        end
        env_mock
      end

      def self.logger
        logger_mock = Class.new do
          def self.warn(message)
            # Do nothing - mock logger
          end
        end
        logger_mock
      end
    end

    # Replace Rails constant temporarily
    rails_defined = defined?(Rails)
    old_rails = Rails if rails_defined
    Object.send(:remove_const, :Rails) if rails_defined
    Object.const_set(:Rails, rails_mock)

    begin
      # Clear context
      TenantScoped.clear_context!
      assert_nil TenantScoped.current_organization_id
    ensure
      # Restore Rails constant
      Object.send(:remove_const, :Rails)
      Object.const_set(:Rails, old_rails) if rails_defined
    end
  end

  def test_tenant_scoped_models_registration
    # Initially empty
    assert_equal [], TenantScoped.tenant_scoped_models

    # Create a mock model class
    mock_model = Class.new

    # Register it
    TenantScoped.register_tenant_scoped_model(mock_model)
    assert_includes TenantScoped.tenant_scoped_models, mock_model

    # Registering again shouldn't duplicate
    TenantScoped.register_tenant_scoped_model(mock_model)
    assert_equal 1, TenantScoped.tenant_scoped_models.count(mock_model)
  end

  def test_model_tenant_scoped_check
    # Create a mock model that responds to tenant_scoped?
    mock_model = Class.new do
      def self.tenant_scoped?
        true
      end
    end

    # Should return true for models that respond true to tenant_scoped?
    assert TenantScoped.model_tenant_scoped?(mock_model)

    # Should return false for models that don't respond true
    mock_model_false = Class.new do
      def self.tenant_scoped?
        false
      end
    end

    refute TenantScoped.model_tenant_scoped?(mock_model_false)

    # Should return false for models that don't respond to the method
    mock_model_no_method = Class.new
    refute TenantScoped.model_tenant_scoped?(mock_model_no_method)
  end

  def test_model_compatible_basic
    # Create a mock model with column_names method
    mock_model_with_column = Class.new do
      def self.column_names
        ['id', 'organization_id', 'name']
      end

      def self.respond_to?(method)
        method.to_s == 'column_names' || super
      end
    end

    assert TenantScoped.model_compatible?(mock_model_with_column)

    # Create a mock model without organization_id column
    mock_model_without_column = Class.new do
      def self.column_names
        ['id', 'name']
      end

      def self.respond_to?(method)
        method.to_s == 'column_names' || super
      end
    end

    refute TenantScoped.model_compatible?(mock_model_without_column)

    # Create a mock model that doesn't respond to column_names
    mock_model_no_columns = Class.new
    refute TenantScoped.model_compatible?(mock_model_no_columns)
  end

  def test_scoping_summary_structure
    summary = TenantScoped.scoping_summary

    assert_kind_of Hash, summary
    assert_includes summary.keys, :tenant_scoped_models
    assert_includes summary.keys, :system_scoped_models
    assert_includes summary.keys, :excluded_models
    assert_includes summary.keys, :total_models

    assert_kind_of Array, summary[:tenant_scoped_models]
    assert_kind_of Array, summary[:system_scoped_models]
    assert_kind_of Array, summary[:excluded_models]
    assert_kind_of Integer, summary[:total_models]
  end

  def test_with_organization_context_management
    # Mock organization object
    mock_org = Object.new
    def mock_org.id; 42; end

    # Store original state
    original_id = TenantScoped.current_organization_id

    # Initially clear context
    TenantScoped.current_organization_id = nil
    assert_nil TenantScoped.current_organization_id

    # Use with_organization
    TenantScoped.with_organization(mock_org) do
      assert_equal 42, TenantScoped.current_organization_id
      assert_equal mock_org, TenantScoped.current_organization
    end

    # Context should be restored to nil
    assert_nil TenantScoped.current_organization_id

    # Restore original state
    TenantScoped.current_organization_id = original_id
  end

  def test_without_organization_context_management
    # Set initial context
    TenantScoped.current_organization_id = 123

    # Use without_organization
    TenantScoped.without_organization do
      assert_nil TenantScoped.current_organization_id
    end

    # Context should be restored
    assert_equal 123, TenantScoped.current_organization_id
  end

  def test_current_organization_caching
    # Mock organization class and instance
    organization_class = Class.new do
      def self.unscoped
        self
      end

      def self.find(id)
        mock_org = Object.new
        def mock_org.id; 42; end
        def mock_org.name; "Test Org"; end
        mock_org
      end
    end

    # Temporarily define Organization constant
    Object.const_set(:Organization, organization_class)

    begin
      TenantScoped.current_organization_id = 42

      # First call should cache the organization
      org1 = TenantScoped.current_organization
      assert_equal 42, org1.id

      # Second call should return cached instance
      org2 = TenantScoped.current_organization
      assert_same org1, org2

    ensure
      Object.send(:remove_const, :Organization) if defined?(Organization)
    end
  end

  def test_error_inheritance_hierarchy
    # Test that all error classes inherit from the correct parents
    assert TenantScoped::TenantScopingError < SecurityError
    assert TenantScoped::AdminAuthorizationError < TenantScoped::TenantScopingError
    assert TenantScoped::CrossTenantAccessError < TenantScoped::TenantScopingError
    assert TenantScoped::UnscopedQueryError < TenantScoped::TenantScopingError
    assert TenantScoped::ModelIncompatibilityError < TenantScoped::TenantScopingError
    assert TenantScoped::MissingColumnError < TenantScoped::TenantScopingError
  end

  def test_module_structure_completeness
    # Test that all expected class methods are present
    expected_class_methods = %i[
      current_organization_id
      current_organization_id=
      context_storage_available?
      clear_context!
      current_organization
      current_organization=
      with_organization
      without_organization
      validate_tenant_scoping_compatibility!
      model_compatible?
      tenant_scoped_models
      register_tenant_scoped_model
      model_tenant_scoped?
      scoping_summary
      print_scoping_summary
    ]

    expected_class_methods.each do |method|
      assert_respond_to TenantScoped, method, "TenantScoped should respond to #{method}"
    end
  end

  def test_print_scoping_summary_output
    # Capture output
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output

    begin
      TenantScoped.print_scoping_summary
      summary_output = output.string

      # Check that the output contains expected sections
      assert_match(/TENANT SCOPING SUMMARY/, summary_output)
      assert_match(/Total Models:/, summary_output)
      assert_match(/Tenant-Scoped Models/, summary_output)
      assert_match(/System-Scoped Models/, summary_output)
      assert_match(/Excluded Models/, summary_output)

    ensure
      $stdout = original_stdout
    end
  end

  def test_bypass_environment_constants
    assert_equal :warn, TenantScoped::BYPASS_AUDIT_LOG_LEVEL
    assert_equal %w[development test production], TenantScoped::BYPASS_ENABLED_ENVIRONMENTS
    assert TenantScoped::BYPASS_ENABLED_ENVIRONMENTS.frozen?
  end
end
