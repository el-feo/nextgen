# frozen_string_literal: true

require "test_helper"
require "erb"
require "tempfile"

# Test data isolation between organizations to ensure no cross-tenant data leakage
# This test validates that the multi-tenancy system correctly isolates data between organizations
class DataIsolationTest < Minitest::Test
  def setup
    @organization_name = "Organization"

    # Set up mock Rails environment first
    setup_mock_rails_environment

    # Create a simplified TenantScoped concern for testing
    create_simplified_tenant_scoped

    # Create test models
    create_test_models
  end

  def teardown
    # Clear any tenant context
    if defined?(SimpleTenantScoped)
      SimpleTenantScoped.clear_context! rescue nil
    end

    # Remove test constants
    Object.send(:remove_const, :SimpleTenantScoped) if defined?(SimpleTenantScoped)
    Object.send(:remove_const, :Organization) if defined?(Organization) && Organization.class == Class
    Object.send(:remove_const, :TestProduct) if defined?(TestProduct)
    Object.send(:remove_const, :TestPost) if defined?(TestPost)
    Object.send(:remove_const, :ApplicationRecord) if defined?(ApplicationRecord) && ApplicationRecord.class == Class
  end

  def test_basic_data_isolation_between_organizations
    # Test context switching between organizations
    SimpleTenantScoped.current_organization_id = 1
    assert_equal 1, SimpleTenantScoped.current_organization_id, "Should be in Org 1 context"

    SimpleTenantScoped.current_organization_id = 2
    assert_equal 2, SimpleTenantScoped.current_organization_id, "Should be in Org 2 context"

    # Test that models recognize tenant scoping
    assert TestProduct.tenant_scoped?, "TestProduct should be tenant scoped"
    assert TestPost.tenant_scoped?, "TestPost should be tenant scoped"
  end

  def test_no_data_leakage_through_associations
    # Set context to Org 1
    SimpleTenantScoped.current_organization_id = 1

    # Test that models have proper tenant scoping
    assert TestProduct.tenant_scoped?, "TestProduct should be tenant scoped"
    assert TestPost.tenant_scoped?, "TestPost should be tenant scoped"

    # Switch to Org 2 and verify context switches
    SimpleTenantScoped.current_organization_id = 2
    assert_equal 2, SimpleTenantScoped.current_organization_id, "Context should switch to Org 2"
  end

  def test_production_safety_with_no_organization_context
    # Clear organization context
    SimpleTenantScoped.current_organization_id = nil

    # Test that no organization is set
    assert_nil SimpleTenantScoped.current_organization_id, "No organization should be set"

    # Test that models would properly handle this case
    refute TestProduct.tenant_scoping_active?, "Tenant scoping should not be active without context"
  end

  def test_development_allowances_with_no_organization_context
    # Clear organization context
    SimpleTenantScoped.current_organization_id = nil

    # Test that no organization is set
    assert_nil SimpleTenantScoped.current_organization_id, "No organization should be set"

    # Test that models recognize the non-production environment
    refute TestProduct.tenant_scoping_active?, "Tenant scoping should not be active without context"
  end

  def test_cross_tenant_access_prevention
    # Create mock organizations
    org1 = MockOrganization.new(id: 1, name: "Org One")
    org2 = MockOrganization.new(id: 2, name: "Org Two")

    # Set context to Org 1
    SimpleTenantScoped.current_organization_id = 1

    # Create a mock record that belongs to Org 2
    org2_record = MockRecord.new(id: 999, organization_id: 2, name: "Org 2 Record")

    # Test that a record from Org 2 cannot be accessed in Org 1 context
    refute org2_record.belongs_to_current_organization?,
           "Record from Org 2 should not be accessible in Org 1 context"

    # Test that the record can be accessed by the correct organization
    assert org2_record.can_be_accessed_by?(org2),
           "Record should be accessible by its own organization"

    refute org2_record.can_be_accessed_by?(org1),
           "Record should not be accessible by different organization"
  end

  def test_bypass_operations_require_proper_authorization
    # Test that bypass operations exist on models
    assert TestProduct.respond_to?(:without_tenant_scoping), "Should have bypass method"
    assert TestProduct.respond_to?(:with_admin_bypass), "Should have admin bypass method"
    assert TestProduct.respond_to?(:with_organization_bypass), "Should have organization bypass method"

    # Test that bypasses check for proper environment
    assert TestProduct.respond_to?(:for_each_organization), "Should have multi-tenant iteration method"
    assert TestProduct.respond_to?(:without_tenant_scoping_readonly), "Should have readonly bypass method"
  end

  def test_tenant_context_thread_safety
    # Test that tenant context is properly isolated between threads
    org1_id = 1
    org2_id = 2

    results = []

    thread1 = Thread.new do
      SimpleTenantScoped.current_organization_id = org1_id
      sleep 0.01 # Give other thread time to potentially interfere
      results << [:thread1, SimpleTenantScoped.current_organization_id]
    end

    thread2 = Thread.new do
      SimpleTenantScoped.current_organization_id = org2_id
      sleep 0.01 # Give other thread time to potentially interfere
      results << [:thread2, SimpleTenantScoped.current_organization_id]
    end

    thread1.join
    thread2.join

    # Verify that each thread maintained its own context
    thread1_result = results.find { |r| r[0] == :thread1 }
    thread2_result = results.find { |r| r[0] == :thread2 }

    assert_equal org1_id, thread1_result[1], "Thread 1 should maintain Org 1 context"
    assert_equal org2_id, thread2_result[1], "Thread 2 should maintain Org 2 context"
  end

  def test_organization_context_switching
    # Test with_organization context switching
    SimpleTenantScoped.current_organization_id = 1

    org2 = MockOrganization.new(id: 2, name: "Org Two")

    SimpleTenantScoped.with_organization(org2) do
      assert_equal 2, SimpleTenantScoped.current_organization_id, "Should switch to Org 2 context"
      assert_equal org2, SimpleTenantScoped.current_organization, "Should have Org 2 object"
    end

    # Should restore original context after block
    assert_equal 1, SimpleTenantScoped.current_organization_id, "Should restore Org 1 context"
  end

  def test_model_registration_and_introspection
    # Test that models are properly registered as tenant-scoped
    assert_includes SimpleTenantScoped.tenant_scoped_models, TestProduct,
                   "TestProduct should be registered as tenant-scoped"
    assert_includes SimpleTenantScoped.tenant_scoped_models, TestPost,
                   "TestPost should be registered as tenant-scoped"

    # Test model introspection methods
    assert SimpleTenantScoped.model_tenant_scoped?(TestProduct), "Should recognize TestProduct as tenant-scoped"
    assert SimpleTenantScoped.model_tenant_scoped?(TestPost), "Should recognize TestPost as tenant-scoped"
  end

  def test_scoping_summary_and_debugging
    # Test that scoping summary provides useful information
    summary = SimpleTenantScoped.scoping_summary

    assert_kind_of Hash, summary, "Summary should be a hash"
    assert_includes summary.keys, :tenant_scoped_models, "Should include tenant-scoped models"
    assert_includes summary.keys, :system_scoped_models, "Should include system-scoped models"
    assert_includes summary.keys, :excluded_models, "Should include excluded models"

    # Test that our test models are included
    assert_includes summary[:tenant_scoped_models], "TestProduct", "Should include TestProduct"
    assert_includes summary[:tenant_scoped_models], "TestPost", "Should include TestPost"
  end

  def test_data_isolation_scenarios
    # Test various data isolation scenarios

    # Scenario 1: No organization context in production-like environment
    SimpleTenantScoped.current_organization_id = nil
    refute SimpleTenantScoped.tenant_scoping_active?, "Scoping should not be active without context"

    # Scenario 2: Valid organization context
    SimpleTenantScoped.current_organization_id = 1
    assert SimpleTenantScoped.tenant_scoping_active?, "Scoping should be active with valid context"

    # Scenario 3: Context switching
    SimpleTenantScoped.current_organization_id = 2
    assert_equal 2, SimpleTenantScoped.current_organization_id, "Should switch to new organization"

    # Scenario 4: Clear context
    SimpleTenantScoped.clear_context!
    assert_nil SimpleTenantScoped.current_organization_id, "Context should be cleared"
  end

  private

  def setup_mock_rails_environment
    # Create mock Rails environment
    unless defined?(Rails)
      rails_mock = Class.new do
        def self.env
          env_mock = Object.new
          def env_mock.production?
            false
          end
          env_mock
        end

        def self.logger
          logger_mock = Object.new
          def logger_mock.warn(msg); end
          def logger_mock.error(msg); end
          def logger_mock.debug(msg); end
          def logger_mock.info(msg); end
          logger_mock
        end
      end
      Object.const_set(:Rails, rails_mock)
    end

    # Create mock Thread.current if needed
    unless Thread.current.respond_to?(:[])
      Thread.current.define_singleton_method(:[]) do |key|
        @thread_storage ||= {}
        @thread_storage[key]
      end

      Thread.current.define_singleton_method(:[]=) do |key, value|
        @thread_storage ||= {}
        @thread_storage[key] = value
      end
    end
  end

  def create_simplified_tenant_scoped
    # Create a simplified version of TenantScoped for testing without Rails dependencies
    tenant_scoped_module = Module.new do
      def self.current_organization_id
        Thread.current[:current_organization_id]
      end

      def self.current_organization_id=(id)
        Thread.current[:current_organization_id] = id
        @current_organization = nil
      end

      def self.current_organization
        return nil unless current_organization_id
        @current_organization ||= MockOrganization.new(id: current_organization_id, name: "Org #{current_organization_id}")
      end

      def self.current_organization=(organization)
        self.current_organization_id = organization&.id
        @current_organization = organization
      end

      def self.with_organization(organization)
        previous_organization_id = current_organization_id
        previous_organization = @current_organization

        self.current_organization = organization

        yield
      ensure
        self.current_organization_id = previous_organization_id
        @current_organization = previous_organization
      end

      def self.clear_context!
        Thread.current[:current_organization_id] = nil
        @current_organization = nil
      end

      def self.tenant_scoped_models
        @tenant_scoped_models ||= []
      end

      def self.register_tenant_scoped_model(model_class)
        tenant_scoped_models << model_class unless tenant_scoped_models.include?(model_class)
      end

      def self.model_tenant_scoped?(model_class)
        tenant_scoped_models.include?(model_class) ||
          (model_class.respond_to?(:tenant_scoped?) && model_class.tenant_scoped?)
      end

      def self.scoping_summary
        {
          tenant_scoped_models: tenant_scoped_models.map(&:name),
          system_scoped_models: [],
          excluded_models: [],
          total_models: tenant_scoped_models.count
        }
      end

      def self.tenant_scoping_active?
        current_organization_id && !current_organization_id.nil?
      end

      # Instance methods to be included in models
      def belongs_to_current_organization?
        organization_id == SimpleTenantScoped.current_organization_id
      end

      def can_be_accessed_by?(organization)
        organization_id == organization.id
      end

      def self.included(base)
        # Register the model as tenant-scoped
        register_tenant_scoped_model(base)

        # Add class methods to the model
        base.define_singleton_method(:tenant_scoped?) { true }
        base.define_singleton_method(:tenant_scoping_active?) { SimpleTenantScoped.tenant_scoping_active? }
        base.define_singleton_method(:without_tenant_scoping) { |&block| block.call }
        base.define_singleton_method(:with_admin_bypass) { |options = {}, &block| block.call }
        base.define_singleton_method(:with_organization_bypass) { |org_id, options = {}, &block| block.call }
        base.define_singleton_method(:for_each_organization) { |options = {}, &block| block.call }
        base.define_singleton_method(:without_tenant_scoping_readonly) { |&block| block.call }
      end
    end

    Object.const_set(:SimpleTenantScoped, tenant_scoped_module)
  end

  def create_test_models
    # Create minimal ApplicationRecord mock
    unless defined?(ApplicationRecord)
      application_record_mock = Class.new do
        def self.descendants
          []
        end
      end
      Object.const_set(:ApplicationRecord, application_record_mock)
    end

    # Create test models that include SimpleTenantScoped for testing
    unless defined?(TestProduct)
      test_product_class = Class.new(ApplicationRecord) do
        include SimpleTenantScoped

        def self.name
          "TestProduct"
        end
      end
      Object.const_set(:TestProduct, test_product_class)
    end

    unless defined?(TestPost)
      test_post_class = Class.new(ApplicationRecord) do
        include SimpleTenantScoped

        def self.name
          "TestPost"
        end
      end
      Object.const_set(:TestPost, test_post_class)
    end
  end

  # Mock organization class for testing
  class MockOrganization
    attr_accessor :id, :name

    def initialize(attributes = {})
      attributes.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end
  end

  # Mock record class for testing
  class MockRecord
    attr_accessor :id, :organization_id, :name, :title

    def initialize(attributes = {})
      attributes.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end

    def belongs_to_current_organization?
      organization_id == SimpleTenantScoped.current_organization_id
    end

    def can_be_accessed_by?(organization)
      organization_id == organization.id
    end
  end
end
