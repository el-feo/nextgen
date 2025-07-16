# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"
require "stringio"

class MultiTenancyGeneratorTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("nextgen_multi_tenancy_test")
    @original_dir = Dir.pwd

    # Create basic Rails app structure
    setup_rails_app_structure

    @generator = MultiTenancyGenerator.new([], {}, { destination_root: @temp_dir })
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  def test_generator_loads_successfully
    assert_instance_of MultiTenancyGenerator, @generator
    assert_respond_to @generator, :execute
  end

  def test_generator_has_class_options
    options = MultiTenancyGenerator.class_options

    # Test that key options are defined
    assert_includes options.keys, :skip_tests
    assert_includes options.keys, :skip_concerns
    assert_includes options.keys, :skip_migrations
    assert_includes options.keys, :organization_name
    assert_includes options.keys, :force_overwrite
  end

  def test_template_files_exist
    # Test that essential template files exist
    template_dir = File.expand_path("../../../lib/nextgen/generators/multi_tenancy", __dir__)

    essential_templates = %w[
      organization.rb.erb
      role.rb.erb
      membership.rb.erb
      tenant_scoped.rb.erb
      system_scoped.rb.erb
    ]

    essential_templates.each do |template|
      template_path = File.join(template_dir, template)
      assert File.exist?(template_path), "Essential template #{template} should exist at #{template_path}"
    end
  end

  def test_migration_template_files_exist
    # Test that migration template files exist
    migration_template_dir = File.expand_path("../../../lib/nextgen/generators/multi_tenancy/migration_templates", __dir__)

    migration_templates = %w[
      create_organizations.rb.erb
      create_roles.rb.erb
      create_memberships.rb.erb
      add_organization_id_to_table.rb.erb
    ]

    migration_templates.each do |template|
      template_path = File.join(migration_template_dir, template)
      assert File.exist?(template_path), "Migration template #{template} should exist at #{template_path}"
    end
  end

  def test_generator_responds_to_required_methods
    # Test that generator has the main public method
    assert_respond_to @generator, :execute, "Generator should respond to execute"

    # Test that private methods exist (even though they're private, they should be defined)
    private_methods = %w[
      generate_organization_model
      generate_role_model
      generate_membership_model
      generate_tenant_scoped_concern
      scan_existing_models_for_tenant_integration
      generate_data_migration_guidance
      validate_user_model
      parse_and_validate_options
      check_compatibility
    ]

    private_methods.each do |method|
      assert @generator.private_methods.include?(method.to_sym), "Generator should have private method #{method}"
    end
  end

  def test_generator_source_root_is_correct
    expected_source_root = File.expand_path("../../../lib/nextgen/generators/multi_tenancy", __dir__)
    assert_equal expected_source_root, @generator.class.source_root
  end

  # This test will be expanded in future iterations
  def test_generator_execution_integration
    skip "Full integration test - requires more setup"

    # This is where we'll add comprehensive integration tests
    # that actually run the generator and verify file creation
    # For now, we skip this to focus on basic structure validation
  end

  private

  def setup_rails_app_structure
    Dir.chdir(@temp_dir)

    # Create minimal directory structure
    %w[
      app/models
      app/models/concerns
      config
      config/initializers
      db/migrate
    ].each { |dir| FileUtils.mkdir_p(dir) }

    # Create minimal User model for validation
    File.write("app/models/user.rb", <<~RUBY)
      class User < ApplicationRecord
        validates :email, presence: true
      end
    RUBY

    # Create application record
    File.write("app/models/application_record.rb", <<~RUBY)
      class ApplicationRecord < ActiveRecord::Base
        self.abstract_class = true
      end
    RUBY

    # Create routes file
    File.write("config/routes.rb", <<~RUBY)
      Rails.application.routes.draw do
        # Routes placeholder
      end
    RUBY
  end
end
