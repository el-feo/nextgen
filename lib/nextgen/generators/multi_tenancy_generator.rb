# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module Nextgen
  module Generators
    class MultiTenancyGenerator < Rails::Generators::Base
      desc "Add multi-tenancy support to your Rails application with organizations, roles, and tenant scoping"

      # Set the source root for templates
      source_root File.expand_path("multi_tenancy", __dir__)

      # Define class options for generator configuration
      class_option :skip_tests, type: :boolean, default: false, desc: "Skip generating tests"
      class_option :skip_concerns, type: :boolean, default: false, desc: "Skip generating tenant scoping concerns"
      class_option :skip_migrations, type: :boolean, default: false, desc: "Skip generating migrations"
      class_option :organization_name, type: :string, default: "Organization", desc: "Name for the organization model"
      class_option :role_name, type: :string, default: "Role", desc: "Name for the role model"
      class_option :membership_name, type: :string, default: "Membership", desc: "Name for the membership model"
      class_option :tenant_column, type: :string, default: "organization_id", desc: "Column name for tenant foreign key"
      class_option :force_overwrite, type: :boolean, default: false, desc: "Force overwrite existing files without prompting"

      def self.exit_on_failure?
        true
      end

      # Main generator execution flow
      def execute
        log_section "NEXTGEN MULTI-TENANCY GENERATOR"
        parse_and_validate_options
        check_compatibility
        validate_user_model
        get_user_confirmation unless options[:force_overwrite]

        generate_organization_model
        generate_role_model
        generate_membership_model
        add_user_model_associations
        generate_tenant_scoped_concern unless @skip_concerns
        generate_tenant_scoping_initializer

        log_completion("Multi-tenancy setup completed successfully!")
      end

      private

      # Parse and validate generator options
      def parse_and_validate_options
        log_step "Parsing generator options...", :info

        # Validate organization name
        @organization_name = options[:organization_name].classify
        unless valid_model_name?(@organization_name)
          log_step "Invalid organization name: #{options[:organization_name]}", :error
          say "Organization name must be a valid Ruby class name", :red
          exit(1)
        end

        # Validate role name
        @role_name = options[:role_name].classify
        unless valid_model_name?(@role_name)
          log_step "Invalid role name: #{options[:role_name]}", :error
          say "Role name must be a valid Ruby class name", :red
          exit(1)
        end

        # Validate membership name
        @membership_name = options[:membership_name].classify
        unless valid_model_name?(@membership_name)
          log_step "Invalid membership name: #{options[:membership_name]}", :error
          say "Membership name must be a valid Ruby class name", :red
          exit(1)
        end

        # Validate tenant column name
        @tenant_column = options[:tenant_column].underscore
        unless valid_column_name?(@tenant_column)
          log_step "Invalid tenant column name: #{options[:tenant_column]}", :error
          say "Tenant column must be a valid database column name", :red
          exit(1)
        end

        # Store configuration flags
        @skip_tests = options[:skip_tests]
        @skip_concerns = options[:skip_concerns]
        @skip_migrations = options[:skip_migrations]
        @force_overwrite = options[:force_overwrite]

        log_step "Configuration parsed successfully:", :success
        log_step "  Organization model: #{@organization_name}", :progress
        log_step "  Role model: #{@role_name}", :progress
        log_step "  Membership model: #{@membership_name}", :progress
        log_step "  Tenant column: #{@tenant_column}", :progress
        log_step "  Skip tests: #{@skip_tests}", :progress
        log_step "  Skip concerns: #{@skip_concerns}", :progress
        log_step "  Skip migrations: #{@skip_migrations}", :progress
        log_step "  Force overwrite: #{@force_overwrite}", :progress
      end

      # Check for Rails 8 compatibility and detect test framework
      def check_compatibility
        log_step "Checking Rails compatibility...", :info

        unless rails_version_compatible?
          log_step "This generator requires Rails 6.0 or higher. Current version: #{Rails.version}", :error
          say "Supported Rails versions: 6.0, 6.1, 7.0, 7.1, 8.0+", :yellow
          exit(1)
        end

        rails_version = Gem::Version.new(Rails.version)
        if rails_version >= Gem::Version.new("8.0.0")
          log_step "Rails #{Rails.version} detected (Rails 8+ compatible)", :success
        elsif rails_version >= Gem::Version.new("7.0.0")
          log_step "Rails #{Rails.version} detected (Rails 7.x compatible)", :success
        else
          log_step "Rails #{Rails.version} detected (Rails 6.x compatible)", :success
        end

        @test_framework = detect_test_framework
        case @test_framework
        when :rspec
          log_step "Test framework: RSpec detected", :success
        when :minitest
          log_step "Test framework: Minitest detected", :success
        when :none
          log_step "No test framework detected - tests will be skipped", :warning
        end
      end

      # Validate that User model exists
      def validate_user_model
        log_step "Validating User model...", :info

        unless user_model_exists?
          log_step "User model not found!", :error
          say <<~ERROR, :red

            This generator requires a User model to exist in your application.
            Please create a User model first:

              rails generate model User name:string email:string
              rails db:migrate

            Then run this generator again.
          ERROR
          exit(1)
        end

        log_step "User model found", :success
      end

      # Get user confirmation before making changes
      def get_user_confirmation
        say "\nThis generator will:", :yellow
        say "• Create #{@organization_name}, #{@role_name}, and #{@membership_name} models"
        say "• Add migrations for multi-tenancy tables" unless @skip_migrations
        say "• Create a TenantScoped concern for automatic scoping" unless @skip_concerns
        say "• Modify existing models to include #{@tenant_column}"
        say "• Add foreign key constraints and indexes"
        say "• Generate test files" unless @skip_tests

        unless yes?("\nProceed with multi-tenancy setup? (y/n)", :yellow)
          say "Multi-tenancy setup cancelled.", :red
          exit(0)
        end
      end

      # Set up logging for user feedback
      def setup_logging
        say "\n" + "="*60, :cyan
        say "  NEXTGEN MULTI-TENANCY GENERATOR", :cyan
        say "="*60, :cyan
        say "Starting multi-tenancy setup for your Rails application...\n", :green
      end

      # Enhanced logging methods for consistent user feedback
      def log_step(message, status = :info)
        case status
        when :success
          say "✓ #{message}", :green
        when :info
          say "→ #{message}", :blue
        when :warning
          say "⚠ #{message}", :yellow
        when :error
          say "✗ #{message}", :red
        when :progress
          say "• #{message}", :cyan
        else
          say message, :white
        end
      end

      def log_section(title)
        say "\n" + "-" * 50, :cyan
        say "#{title}", :cyan
        say "-" * 50, :cyan
      end

      def log_completion(message = "Multi-tenancy setup completed successfully!")
        say "\n" + "="*60, :green
        say "  #{message}", :green
        say "="*60, :green
      end

      def log_file_action(action, file_path, details = nil)
        case action
        when :create
          say "      create  #{file_path}", :green
        when :modify
          say "      modify  #{file_path}", :yellow
        when :skip
          say "      skip    #{file_path} (already exists)", :yellow
        end
        say "              #{details}", :light_blue if details
      end

      # Generate the Organization model
      def generate_organization_model
        log_section "GENERATING ORGANIZATION MODEL"
        log_step "Creating #{@organization_name} model...", :info

        model_file_path = "app/models/#{@organization_name.underscore}.rb"

        if File.exist?(model_file_path) && !@force_overwrite
          log_file_action :skip, model_file_path, "Use --force-overwrite to replace"
        else
          template(
            "organization.rb.erb",
            model_file_path
          )
          log_file_action :create, model_file_path, "Multi-tenant organization model with validations and indexes"
        end

        # Generate migration unless skipped
        unless @skip_migrations
          generate_organization_migration
        end

        log_step "#{@organization_name} model created successfully", :success
      end

      # Generate the migration for organizations table
      def generate_organization_migration
        log_step "Creating migration for #{@organization_name.underscore.pluralize} table...", :info

        migration_template(
          "migration_templates/create_organizations.rb.erb",
          "db/migrate/create_#{@organization_name.underscore.pluralize}.rb"
        )

        log_file_action :create, "db/migrate/create_#{@organization_name.underscore.pluralize}.rb",
                       "Migration with proper indexes and constraints"
      end

      # Generate the Role model
      def generate_role_model
        log_section "GENERATING ROLE MODEL"
        log_step "Creating #{@role_name} model...", :info

        model_file_path = "app/models/#{@role_name.underscore}.rb"

        if File.exist?(model_file_path) && !@force_overwrite
          log_file_action :skip, model_file_path, "Use --force-overwrite to replace"
        else
          template(
            "role.rb.erb",
            model_file_path
          )
          log_file_action :create, model_file_path, "Role model with enum validation for admin/member/owner types"
        end

        # Generate migration unless skipped
        unless @skip_migrations
          generate_role_migration
        end

        log_step "#{@role_name} model created successfully", :success
      end

      # Generate the migration for roles table
      def generate_role_migration
        log_step "Creating migration for #{@role_name.underscore.pluralize} table...", :info

        migration_template(
          "migration_templates/create_roles.rb.erb",
          "db/migrate/create_#{@role_name.underscore.pluralize}.rb"
        )

        log_file_action :create, "db/migrate/create_#{@role_name.underscore.pluralize}.rb",
                       "Migration with enum validation and default role seed data"
      end

      # Generate the Membership model
      def generate_membership_model
        log_section "GENERATING MEMBERSHIP MODEL"
        log_step "Creating #{@membership_name} model...", :info

        model_file_path = "app/models/#{@membership_name.underscore}.rb"

        if File.exist?(model_file_path) && !@force_overwrite
          log_file_action :skip, model_file_path, "Use --force-overwrite to replace"
        else
          template(
            "membership.rb.erb",
            model_file_path
          )
          log_file_action :create, model_file_path, "Join table model connecting Users, Organizations, and Roles"
        end

        # Generate migration unless skipped
        unless @skip_migrations
          generate_membership_migration
        end

        log_step "#{@membership_name} model created successfully", :success
      end

      # Generate the migration for memberships table
      def generate_membership_migration
        log_step "Creating migration for #{@membership_name.underscore.pluralize} table...", :info

        migration_template(
          "migration_templates/create_memberships.rb.erb",
          "db/migrate/create_#{@membership_name.underscore.pluralize}.rb"
        )

        log_file_action :create, "db/migrate/create_#{@membership_name.underscore.pluralize}.rb",
                       "Join table with foreign key constraints and composite indexes"
      end

      # Add associations to the existing User model
      def add_user_model_associations
        log_section "ADDING USER MODEL ASSOCIATIONS"
        log_step "Modifying User model to add multi-tenancy associations...", :info

        user_model_path = "app/models/user.rb"

        # Read the current User model content
        user_content = File.read(user_model_path)

        # Check if associations already exist
        if user_content.include?("has_many :#{@membership_name.underscore.pluralize}") || user_content.include?("has_many :memberships")
          log_file_action :skip, user_model_path, "Multi-tenancy associations already exist"
          return
        end

        # Define the associations to add
        associations = <<~ASSOCIATIONS.strip
          # Multi-tenancy associations
          has_many :#{@membership_name.underscore.pluralize}, dependent: :destroy, inverse_of: :user
          has_many :#{@organization_name.underscore.pluralize}, through: :#{@membership_name.underscore.pluralize}
          has_many :#{@role_name.underscore.pluralize}, through: :#{@membership_name.underscore.pluralize}

          # Multi-tenancy methods
          def #{@organization_name.underscore.pluralize}_for_role(role_type)
            #{@organization_name.underscore.pluralize}.joins(:#{@membership_name.underscore.pluralize}).where(
              #{@membership_name.underscore.pluralize}: { #{@role_name.underscore}_id: #{@role_name}.where(role_type: role_type) }
            )
          end

          def role_in_#{@organization_name.underscore}(#{@organization_name.underscore})
            #{@membership_name.underscore.pluralize}.find_by(#{@organization_name.underscore}: #{@organization_name.underscore})&.#{@role_name.underscore}
          end

          def member_of?(#{@organization_name.underscore})
            #{@organization_name.underscore.pluralize}.include?(#{@organization_name.underscore})
          end

          def admin_of?(#{@organization_name.underscore})
            role_in_#{@organization_name.underscore}(#{@organization_name.underscore})&.admin?
          end

          def owner_of?(#{@organization_name.underscore})
            role_in_#{@organization_name.underscore}(#{@organization_name.underscore})&.owner?
          end
        ASSOCIATIONS

        # Find the insertion point (after class declaration but before end)
        if user_content.match(/class User < ApplicationRecord\s*\n/)
          # Insert after the class declaration
          updated_content = user_content.sub(
            /(class User < ApplicationRecord\s*\n)/,
            "\\1\n  #{associations}\n"
          )
        elsif user_content.match(/class User < ActiveRecord::Base\s*\n/)
          # Handle older Rails versions
          updated_content = user_content.sub(
            /(class User < ActiveRecord::Base\s*\n)/,
            "\\1\n  #{associations}\n"
          )
        else
          log_step "Could not find User class declaration pattern", :error
          say "Please manually add the following associations to your User model:", :yellow
          say associations, :cyan
          return
        end

        # Write the updated content back to the file
        File.write(user_model_path, updated_content)

        log_file_action :modify, user_model_path, "Added multi-tenancy associations and helper methods"
        log_step "User model associations added successfully", :success
      end

      # Generate the TenantScoped concern for automatic organization scoping
      def generate_tenant_scoped_concern
        log_section "GENERATING TENANT SCOPED CONCERN"
        log_step "Creating TenantScoped concern for automatic tenant isolation...", :info

        concern_file_path = "app/models/concerns/tenant_scoped.rb"

        if File.exist?(concern_file_path) && !@force_overwrite
          log_file_action :skip, concern_file_path, "Use --force-overwrite to replace"
        else
          template(
            "tenant_scoped.rb.erb",
            concern_file_path
          )
          log_file_action :create, concern_file_path, "Concern for automatic organization scoping with thread-safe context management"
        end

        log_step "TenantScoped concern created successfully", :success
        log_step "Include 'TenantScoped' in models that need organization scoping", :info
        log_step "Include 'TenantScoped::ControllerHelpers' in ApplicationController", :info

        generate_system_scoped_interface unless @skip_concerns
      end

      # Generate the SystemScoped interface for models that should not be tenant-scoped
      def generate_system_scoped_interface
        log_section "GENERATING SYSTEM SCOPED INTERFACE"
        log_step "Creating SystemScoped interface for global models...", :info

        interface_file_path = "app/models/concerns/system_scoped.rb"

        if File.exist?(interface_file_path) && !@force_overwrite
          log_file_action :skip, interface_file_path, "Use --force-overwrite to replace"
        else
          template(
            "system_scoped.rb.erb",
            interface_file_path
          )
          log_file_action :create, interface_file_path, "Interface for models that should not be tenant-scoped"
        end

        log_step "SystemScoped interface created successfully", :success
        log_step "Include 'SystemScoped' in models that should be global (not tenant-specific)", :info
        log_step "Examples: SystemConfiguration, AuditLog, Country, DelayedJob", :info

        generate_tenant_scoping_configuration
      end

      # Generate configuration file for tenant scoping
      def generate_tenant_scoping_configuration
        log_step "Creating tenant scoping configuration...", :info

        config_file_path = "config/initializers/tenant_scoping_configuration.rb"

        if File.exist?(config_file_path) && !@force_overwrite
          log_file_action :skip, config_file_path, "Use --force-overwrite to replace"
        else
          template(
            "tenant_scoping_configuration.rb.erb",
            config_file_path
          )
          log_file_action :create, config_file_path, "Configuration for customizing tenant scoping behavior"
        end

        log_step "Tenant scoping configuration created successfully", :success
      end

      private

      def rails_version_compatible?
        # Support Rails 6.0+ through Rails 8+
        rails_version = Gem::Version.new(Rails.version)
        minimum_version = Gem::Version.new("6.0.0")
        rails_version >= minimum_version
      end

      def detect_test_framework
        # Detect test framework with more comprehensive checks
        if File.exist?("spec/spec_helper.rb") || File.exist?("spec/rails_helper.rb")
          :rspec
        elsif File.exist?("test/test_helper.rb")
          :minitest
        elsif File.exist?("Gemfile")
          # Fallback: check Gemfile for test framework gems
          gemfile_content = File.read("Gemfile")
          if gemfile_content.match?(/gem ['"]rspec-rails['"]/)
            :rspec
          elsif gemfile_content.match?(/gem ['"]minitest['"]/) || gemfile_content.match?(/rails/)
            :minitest
          else
            :none
          end
        else
          :none
        end
      end

      def user_model_exists?
        # Check if User model file exists
        return false unless File.exist?("app/models/user.rb")

        # Check if User class is defined and inherits from ApplicationRecord
        begin
          require Rails.root.join("app/models/user.rb")
          User.is_a?(Class) && User < ApplicationRecord
        rescue => e
          false
        end
      end

      # Generate tenant scoping initializer with query monitoring setup
      def generate_tenant_scoping_initializer
        log_step "Generating tenant scoping initializer...", :info

        destination_file = "config/initializers/tenant_scoping.rb"

        template "tenant_scoping_initializer.rb.erb", destination_file

        log_step "✓ Generated #{destination_file}", :success
      end

      # Validate that a model name is a valid Ruby class name
      def valid_model_name?(name)
        return false if name.blank?
        # Check if it's a valid Ruby constant name
        name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/) && name.constantize rescue false
      rescue NameError
        # If constantize fails, check if it's a valid format at least
        name.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)
      end

      # Validate that a column name is valid for database use
      def valid_column_name?(name)
        return false if name.blank?
        # Check for valid database column name format
        # Must start with letter or underscore, followed by letters, numbers, or underscores
        name.match?(/\A[a-z_][a-z0-9_]*\z/) && name.length <= 63 # PostgreSQL limit
      end
    end
  end
end
