# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class MultiTenancyGeneratorEdgeCasesTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("nextgen_edge_cases_test")
    @original_dir = Dir.pwd
    setup_rails_app_structure

    # Mock Rails environment
    mock_rails_environment

    @generator = MultiTenancyGenerator.new
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  # Test 1: Missing User model detection
  def test_missing_user_model_detection
    # Ensure no User model exists
    FileUtils.rm_f("app/models/user.rb") if File.exist?("app/models/user.rb")

    # Test user_model_exists? method returns false
    refute @generator.send(:user_model_exists?), "user_model_exists? should return false when User model is missing"
  end

  def test_missing_user_model_validation_fails
    # Remove User model if it exists
    FileUtils.rm_f("app/models/user.rb") if File.exist?("app/models/user.rb")

    # Capture output and expect exit
    output = capture_io do
      assert_raises(SystemExit) do
        @generator.send(:validate_user_model)
      end
    end

    # Verify error message contains helpful guidance
    assert_match(/User model not found/, output[0])
    assert_match(/rails generate model User/, output[0])
    assert_match(/rails db:migrate/, output[0])
  end

  def test_user_model_exists_when_file_present_and_valid
    # Create a valid User model
    create_user_model

    # Mock the User class being properly loaded
    user_class = Class.new(ApplicationRecord) do
      def self.name
        "User"
      end
    end

    # Stub the class loading
    @generator.define_singleton_method(:require) { |path| true }
    stub_const("User", user_class)

    assert @generator.send(:user_model_exists?), "user_model_exists? should return true for valid User model"
  end

  def test_user_model_validation_passes_with_valid_model
    # Create a valid User model
    create_user_model

    # Mock successful class loading
    user_class = Class.new(ApplicationRecord) do
      def self.name
        "User"
      end
    end

    @generator.define_singleton_method(:require) { |path| true }
    stub_const("User", user_class)

    # Should not raise or exit
    output = capture_io do
      @generator.send(:validate_user_model)
    end

    assert_match(/User model found/, output[0])
  end

  # Test 2: Models without tables - Abstract Model handling
  def test_abstract_model_detection
    create_abstract_model

    # Create a mock model class that behaves like an abstract model
    abstract_model_class = Class.new(ApplicationRecord) do
      def self.name
        "BaseModel"
      end

      def self.abstract_class?
        true
      end
    end

    model_type = @generator.send(:determine_model_type, abstract_model_class)
    assert_equal :abstract_model, model_type
  end

  def test_abstract_model_handling
    create_abstract_model

    # Create model result for abstract model
    abstract_model_class = Class.new(ApplicationRecord) do
      def self.name
        "BaseModel"
      end

      def self.abstract_class?
        true
      end
    end

    model_result = { model: abstract_model_class, name: "BaseModel", file_path: "app/models/base_model.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/abstract model - no action needed/, output[0])
  end

  # Test 3: Concern detection and handling
  def test_concern_detection_by_name
    concern_class = Class.new do
      def self.name
        "AuditableConcern"
      end

      def self.abstract_class?
        false
      end
    end

    model_type = @generator.send(:determine_model_type, concern_class)
    assert_equal :concern, model_type
  end

  def test_concern_detection_by_module_inclusion
    mock_concern_module = mock_active_support_concern

    concern_class = Class.new do
      define_singleton_method(:name) { "Trackable" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [mock_concern_module] }
    end

    model_type = @generator.send(:determine_model_type, concern_class)
    assert_equal :concern, model_type
  end

  def test_concern_handling
    create_concern_model

    mock_concern_module = mock_active_support_concern

    concern_class = Class.new do
      define_singleton_method(:name) { "AuditableConcern" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [mock_concern_module] }
    end

    model_result = { model: concern_class, name: "AuditableConcern", file_path: "app/models/auditable_concern.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/appears to be a concern - no action needed/, output[0])
  end

  # Test 4: Service object detection and handling
  def test_service_object_detection
    service_patterns = %w[UserRegistrationService EmailHandler OrderCommand UserQuery]

    service_patterns.each do |name|
      service_class = Class.new do
        define_singleton_method(:name) { name }
        define_singleton_method(:abstract_class?) { false }
        define_singleton_method(:included_modules) { [] }
      end

      model_type = @generator.send(:determine_model_type, service_class)
      assert_equal :service_object, model_type, "#{name} should be detected as service object"
    end
  end

  def test_service_object_handling
    create_service_object

    service_class = Class.new do
      define_singleton_method(:name) { "EmailService" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [] }
    end

    model_result = { model: service_class, name: "EmailService", file_path: "app/models/email_service.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/appears to be a service object - no action needed/, output[0])
  end

  # Test 5: Form object detection and handling
  def test_form_object_detection
    form_patterns = %w[UserRegistrationForm ContactFormObject]

    form_patterns.each do |name|
      form_class = Class.new do
        define_singleton_method(:name) { name }
        define_singleton_method(:abstract_class?) { false }
        define_singleton_method(:included_modules) { [] }
        define_singleton_method(:ancestors) { [self] }
      end

      model_type = @generator.send(:determine_model_type, form_class)
      assert_equal :form_object, model_type, "#{name} should be detected as form object"
    end
  end

  def test_form_object_handling
    create_form_object

    form_class = Class.new do
      define_singleton_method(:name) { "ContactForm" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [] }
      define_singleton_method(:ancestors) { [self] }
    end

    model_result = { model: form_class, name: "ContactForm", file_path: "app/models/contact_form.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/appears to be a form object - no action needed/, output[0])
  end

  # Test 6: Decorator detection and handling
  def test_decorator_detection
    decorator_patterns = %w[UserDecorator ProductPresenter]

    decorator_patterns.each do |name|
      decorator_class = Class.new do
        define_singleton_method(:name) { name }
        define_singleton_method(:abstract_class?) { false }
        define_singleton_method(:included_modules) { [] }
        define_singleton_method(:ancestors) { [self] }
      end

      model_type = @generator.send(:determine_model_type, decorator_class)
      assert_equal :decorator, model_type, "#{name} should be detected as decorator"
    end
  end

  def test_decorator_handling
    create_decorator

    decorator_class = Class.new do
      define_singleton_method(:name) { "UserDecorator" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [] }
      define_singleton_method(:ancestors) { [self] }
    end

    model_result = { model: decorator_class, name: "UserDecorator", file_path: "app/models/user_decorator.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/appears to be a decorator - no action needed/, output[0])
  end

  # Test 7: Possibly missing table detection
  def test_possibly_missing_table_detection
    # Create a class that looks like a typical model but inherits from ApplicationRecord
    missing_table_class = Class.new(ApplicationRecord) do
      def self.name
        "Product"
      end

      def self.abstract_class?
        false
      end

      def self.included_modules
        []
      end
    end

    model_type = @generator.send(:determine_model_type, missing_table_class)
    assert_equal :possibly_missing_table, model_type
  end

  def test_possibly_missing_table_handling
    create_model_without_table

    missing_table_class = Class.new(ApplicationRecord) do
      define_singleton_method(:name) { "Product" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [] }
    end

    model_result = { model: missing_table_class, name: "Product", file_path: "app/models/product.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/inherits from ApplicationRecord but has no table/, output[0])
    assert_match(/Create missing migration/, output[0])
    assert_match(/rails generate migration CreateProducts/, output[0])

    # Verify model is stored for potential migration generation
    models_missing_tables = @generator.instance_variable_get(:@models_missing_tables)
    assert_includes models_missing_tables, model_result
  end

  # Test 8: Unknown tableless model handling
  def test_unknown_tableless_model_handling
    # Create a generic class that doesn't fit other patterns
    unknown_class = Class.new do
      define_singleton_method(:name) { "WeirdHelper" }
      define_singleton_method(:abstract_class?) { false }
      define_singleton_method(:included_modules) { [] }
      define_singleton_method(:ancestors) { [self] }
    end

    model_result = { model: unknown_class, name: "WeirdHelper", file_path: "app/models/weird_helper.rb" }
    @generator.instance_variable_set(:@models_without_tables, [model_result])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    assert_match(/unclear model type without database table/, output[0])
    assert_match(/Review if this model should have a database table/, output[0])
    assert_match(/Consider moving to app\/lib/, output[0])
    assert_match(/Consider making it an abstract class/, output[0])
    assert_match(/Add table_name = nil/, output[0])
  end

  # Test 9: Bulk edge case handling
  def test_multiple_edge_cases_handled_together
    # Create multiple models without tables of different types
    models = [
      { model: create_mock_class("BaseModel", abstract: true), name: "BaseModel", file_path: "app/models/base_model.rb" },
      { model: create_mock_class("AuditableConcern", concern: true), name: "AuditableConcern", file_path: "app/models/auditable_concern.rb" },
      { model: create_mock_class("EmailService", service: true), name: "EmailService", file_path: "app/models/email_service.rb" },
      { model: create_mock_class("ContactForm", form: true), name: "ContactForm", file_path: "app/models/contact_form.rb" },
      { model: create_mock_class("UserDecorator", decorator: true), name: "UserDecorator", file_path: "app/models/user_decorator.rb" },
      { model: create_mock_class("Product", missing_table: true), name: "Product", file_path: "app/models/product.rb" },
      { model: create_mock_class("WeirdHelper", unknown: true), name: "WeirdHelper", file_path: "app/models/weird_helper.rb" }
    ]

    @generator.instance_variable_set(:@models_without_tables, models)

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    # Verify each type is handled correctly
    assert_match(/abstract model - no action needed/, output[0])
    assert_match(/appears to be a concern - no action needed/, output[0])
    assert_match(/appears to be a service object - no action needed/, output[0])
    assert_match(/appears to be a form object - no action needed/, output[0])
    assert_match(/appears to be a decorator - no action needed/, output[0])
    assert_match(/inherits from ApplicationRecord but has no table/, output[0])
    assert_match(/unclear model type without database table/, output[0])

    # Verify summary messages
    assert_match(/Found 7 model\(s\) without corresponding database tables/, output[0])
    assert_match(/Processed 7 model\(s\) without tables/, output[0])
  end

  # Test 10: Empty models without tables array
  def test_empty_models_without_tables_array
    @generator.instance_variable_set(:@models_without_tables, [])

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    # Should not process anything
    refute_match(/Found.*model\(s\) without/, output[0])
  end

  def test_nil_models_without_tables
    @generator.instance_variable_set(:@models_without_tables, nil)

    output = capture_io do
      @generator.send(:handle_models_without_tables)
    end

    # Should not process anything and not crash
    refute_match(/Found.*model\(s\) without/, output[0])
  end

  private

  def setup_rails_app_structure
    Dir.chdir(@temp_dir)

    %w[
      app/models
      app/models/concerns
      config
      config/initializers
      db
      db/migrate
    ].each { |dir| FileUtils.mkdir_p(dir) }
  end

  def mock_rails_environment
    # Mock Rails
    rails_module = Module.new do
      def self.version
        "7.1.0"
      end

      def self.root
        Pathname.new(Dir.pwd)
      end
    end

    # Mock ApplicationRecord
    application_record_class = Class.new do
      def self.name
        "ApplicationRecord"
      end
    end

    stub_const("Rails", rails_module)
    stub_const("ApplicationRecord", application_record_class)
  end

  def create_user_model
    File.write("app/models/user.rb", <<~RUBY)
      class User < ApplicationRecord
        has_many :memberships, dependent: :destroy
        has_many :organizations, through: :memberships
      end
    RUBY
  end

  def create_abstract_model
    File.write("app/models/base_model.rb", <<~RUBY)
      class BaseModel < ApplicationRecord
        self.abstract_class = true

        # Common functionality for all models
      end
    RUBY
  end

  def create_concern_model
    File.write("app/models/auditable_concern.rb", <<~RUBY)
      module AuditableConcern
        extend ActiveSupport::Concern

        included do
          # Auditing functionality
        end
      end
    RUBY
  end

  def create_service_object
    File.write("app/models/email_service.rb", <<~RUBY)
      class EmailService
        def self.send_welcome_email(user)
          # Email sending logic
        end
      end
    RUBY
  end

  def create_form_object
    File.write("app/models/contact_form.rb", <<~RUBY)
      class ContactForm
        include ActiveModel::Model

        attr_accessor :name, :email, :message

        validates :name, presence: true
        validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
        validates :message, presence: true
      end
    RUBY
  end

  def create_decorator
    File.write("app/models/user_decorator.rb", <<~RUBY)
      class UserDecorator
        def initialize(user)
          @user = user
        end

        def display_name
          @user.name.presence || "Anonymous"
        end
      end
    RUBY
  end

  def create_model_without_table
    File.write("app/models/product.rb", <<~RUBY)
      class Product < ApplicationRecord
        validates :name, presence: true
        validates :price, presence: true, numericality: { greater_than: 0 }
      end
    RUBY
  end

  def mock_active_support_concern
    Module.new do
      def self.name
        "ActiveSupport::Concern"
      end
    end
  end

  def create_mock_class(name, options = {})
    if options[:missing_table]
      base_class = ApplicationRecord
    else
      base_class = Object
    end

    # Determine the actual class name based on options
    class_name = name
    if options[:concern] && !name.end_with?('Concern')
      class_name = "#{name}Concern"
    elsif options[:service] && !name.end_with?('Service')
      class_name = "#{name}Service"
    elsif options[:form] && !name.end_with?('Form')
      class_name = "#{name}Form"
    elsif options[:decorator] && !name.end_with?('Decorator')
      class_name = "#{name}Decorator"
    end

    Class.new(base_class) do
      define_singleton_method(:name) { class_name }
      define_singleton_method(:abstract_class?) { !!options[:abstract] }

      define_singleton_method(:included_modules) do
        if options[:concern]
          mock_module = Module.new do
            def self.name
              "ActiveSupport::Concern"
            end
          end
          [mock_module]
        else
          []
        end
      end

      define_singleton_method(:ancestors) do
        if options[:missing_table]
          [self, ApplicationRecord]
        else
          [self]
        end
      end
    end
  end

  def stub_const(name, value)
    # Simple constant stubbing for test isolation
    original_const = Object.const_defined?(name) ? Object.const_get(name) : nil
    Object.const_set(name, value)

    # Store for cleanup if needed
    @stubbed_consts ||= {}
    @stubbed_consts[name] = original_const
  end

  def capture_io
    original_stdout = $stdout
    original_stderr = $stderr

    captured_stdout = StringIO.new
    captured_stderr = StringIO.new

    $stdout = captured_stdout
    $stderr = captured_stderr

    yield

    [captured_stdout.string, captured_stderr.string]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
