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

        scan_existing_models_for_tenant_integration
        generate_tenant_migrations_for_existing_models
        include_tenant_scoped_concern_in_existing_models
        handle_models_without_tables
        update_existing_model_associations
        offer_missing_table_migrations unless options[:skip_migrations]

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

        scan_existing_models_for_tenant_integration
        generate_tenant_migrations_for_existing_models
        include_tenant_scoped_concern_in_existing_models

        log_completion("Multi-tenancy setup completed successfully!")
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

      # Scan existing models and identify which need organization_id columns
      def scan_existing_models_for_tenant_integration
        log_section "SCANNING EXISTING MODELS"
        log_step "Analyzing existing models for tenant scoping compatibility...", :info

        # Load all models to ensure they're available for introspection
        Rails.application.eager_load! if defined?(Rails.application)

        # Find all ApplicationRecord descendants
        existing_models = discover_existing_models

        if existing_models.empty?
          log_step "No existing models found to analyze", :info
          return
        end

        log_step "Found #{existing_models.count} existing models to analyze", :success

        # Categorize models
        models_needing_org_id = []
        models_already_compatible = []
        models_to_exclude = []
        models_without_tables = []

        existing_models.each do |model_class|
          result = analyze_model_for_tenant_compatibility(model_class)

          case result[:status]
          when :needs_org_id
            models_needing_org_id << result
          when :already_compatible
            models_already_compatible << result
          when :should_exclude
            models_to_exclude << result
          when :no_table
            models_without_tables << result
          end
        end

        # Report findings
        report_model_analysis_results(
          models_needing_org_id,
          models_already_compatible,
          models_to_exclude,
          models_without_tables
        )

        # Store results for use in subsequent tasks
        @models_needing_org_id = models_needing_org_id
        @models_already_compatible = models_already_compatible
        @models_to_exclude = models_to_exclude
        @models_without_tables = models_without_tables
      end

      # Discover all existing models that inherit from ApplicationRecord
      def discover_existing_models
        models = []

        # Ensure Rails is loaded
        return models unless defined?(Rails) && Rails.application

        # Load all files to ensure all models are defined
        Rails.application.eager_load!

        # Find all classes that inherit from ApplicationRecord
        ObjectSpace.each_object(Class).select do |klass|
          begin
            # Check if class inherits from ApplicationRecord and has a valid name
            if klass < ApplicationRecord &&
               !klass.abstract_class? &&
               klass.name.present? &&
               !klass.name.include?("Anonymous") &&
               !klass.name.include?("HABTM_")

              models << klass
            end
          rescue => e
            # Skip classes that cause issues during introspection
            log_step "Skipping model #{klass.name || 'unnamed'}: #{e.message}", :debug if options[:verbose]
          end
        end

        # Sort by name for consistent output
        models.sort_by(&:name)
      end

      # Analyze a model to determine its tenant compatibility status
      def analyze_model_for_tenant_compatibility(model_class)
        model_name = model_class.name
        result = {
          model: model_class,
          name: model_name,
          table_name: nil,
          status: nil,
          reason: nil,
          recommendations: []
        }

        begin
          # Check if model has a table
          unless model_class.table_exists?
            result[:status] = :no_table
            result[:reason] = "Model does not have a corresponding database table"
            result[:recommendations] = ["Create database table", "or remove unused model file"]
            return result
          end

          result[:table_name] = model_class.table_name

          # Check if model should be excluded (system models)
          if should_exclude_model?(model_class)
            result[:status] = :should_exclude
            result[:reason] = "Model is a system model or explicitly excluded"
            result[:recommendations] = ["Consider adding SystemScoped concern for clarity"]
            return result
          end

          # Check if model already has organization_id column
          if model_class.column_names.include?(@tenant_column)
            result[:status] = :already_compatible
            result[:reason] = "Model already has #{@tenant_column} column"
            result[:recommendations] = ["Add TenantScoped concern if not already included"]
            return result
          end

          # Model needs organization_id column
          result[:status] = :needs_org_id
          result[:reason] = "Model does not have #{@tenant_column} column"
          result[:recommendations] = [
            "Add migration to add #{@tenant_column} column",
            "Include TenantScoped concern",
            "Consider data migration for existing records"
          ]

        rescue => e
          result[:status] = :error
          result[:reason] = "Error analyzing model: #{e.message}"
          result[:recommendations] = ["Review model definition", "Check for syntax errors"]
        end

        result
      end

      # Determine if a model should be excluded from tenant scoping
      def should_exclude_model?(model_class)
        model_name = model_class.name

        # System models that typically should not be tenant-scoped
        system_models = %w[
          User
          Organization
          Role
          Membership
          ActiveStorage::Blob
          ActiveStorage::Attachment
          ActiveStorage::VariantRecord
          ActionText::RichText
          ActionText::EncryptedRichText
          ActionMailbox::InboundEmail
          ActiveRecord::SchemaMigration
          ActiveRecord::InternalMetadata
          SolidQueue::Job
          SolidQueue::ScheduledExecution
          SolidQueue::ClaimedExecution
          SolidQueue::BlockedExecution
          SolidQueue::FailedExecution
          SolidQueue::Pause
          SolidQueue::Process
          SolidQueue::ReadyExecution
          Ahoy::Visit
          Ahoy::Event
        ].map(&:downcase)

        # Check if model name matches any system model
        return true if system_models.include?(model_name.downcase)

        # Check if model includes SystemScoped concern
        return true if model_class.included_modules.any? { |mod| mod.name == "SystemScoped" }

        # Check if model is in a namespace that suggests it's a system model
        return true if model_name.match?(/^(ActiveRecord|ActionText|ActionMailbox|ActiveStorage|SolidQueue|Ahoy)::/i)

        # Check if model is explicitly excluded via configuration
        # (This would be loaded from a configuration file in a real implementation)
        excluded_models = get_excluded_models_from_config
        return true if excluded_models.include?(model_name)

        false
      end

      # Get excluded models from configuration (placeholder for future configuration system)
      def get_excluded_models_from_config
        # This would eventually read from a configuration file
        # For now, return empty array
        []
      end

      # Report the results of model analysis
      def report_model_analysis_results(models_needing_org_id, models_already_compatible, models_to_exclude, models_without_tables)
        log_section "MODEL ANALYSIS RESULTS"

        if models_needing_org_id.any?
          log_step "Models requiring #{@tenant_column} column (#{models_needing_org_id.count}):", :warning
          models_needing_org_id.each do |result|
            say "  • #{result[:name]} (#{result[:table_name]})", :yellow
            result[:recommendations].each do |rec|
              say "    - #{rec}", :cyan
            end
          end
          say ""
        end

        if models_already_compatible.any?
          log_step "Models already compatible (#{models_already_compatible.count}):", :success
          models_already_compatible.each do |result|
            say "  • #{result[:name]} (#{result[:table_name]})", :green
          end
          say ""
        end

        if models_to_exclude.any?
          log_step "Models excluded from tenant scoping (#{models_to_exclude.count}):", :info
          models_to_exclude.each do |result|
            say "  • #{result[:name]} - #{result[:reason]}", :blue
          end
          say ""
        end

        if models_without_tables.any?
          log_step "Models without database tables (#{models_without_tables.count}):", :warning
          models_without_tables.each do |result|
            say "  • #{result[:name]} - #{result[:reason]}", :red
          end
          say ""
        end

        # Summary
        total_models = models_needing_org_id.count + models_already_compatible.count +
                      models_to_exclude.count + models_without_tables.count

        log_step "Summary:", :info
        say "  Total models analyzed: #{total_models}", :cyan
        say "  Models needing migration: #{models_needing_org_id.count}", :yellow
        say "  Models already compatible: #{models_already_compatible.count}", :green
        say "  Models excluded: #{models_to_exclude.count}", :blue
        say "  Models without tables: #{models_without_tables.count}", :red

        # Store detailed results for next steps
        if models_needing_org_id.any?
          log_step "Next steps will include generating migrations for models needing #{@tenant_column}", :info
        end
      end

      # Generate migrations to add organization_id to existing models
      def generate_tenant_migrations_for_existing_models
        return unless @models_needing_org_id&.any?

        log_section "GENERATING TENANT MIGRATIONS FOR EXISTING MODELS"
        log_step "Creating migrations to add #{@tenant_column} to existing models...", :info

        @models_needing_org_id.each do |model_result|
          generate_tenant_migration_for_model(model_result)
        end

        log_step "✓ Generated #{@models_needing_org_id.count} migration(s) for existing models", :success
      end

      # Include TenantScoped concern in existing models that need it
      def include_tenant_scoped_concern_in_existing_models
        models_to_update = (@models_needing_org_id || []) + (@models_already_compatible || [])

        return unless models_to_update.any?

        log_section "INCLUDING TENANT SCOPED CONCERN IN EXISTING MODELS"
        log_step "Adding TenantScoped concern to compatible models...", :info

        models_to_update.each do |model_result|
          include_tenant_scoped_in_model(model_result)
        end

        log_step "✓ Updated #{models_to_update.count} model(s) with TenantScoped concern", :success
      end

      # Include TenantScoped concern in a specific model file
      def include_tenant_scoped_in_model(model_result)
        model_class = model_result[:model]
        model_name = model_result[:name]

        # Calculate model file path
        model_file_path = "app/models/#{model_name.underscore}.rb"

        # Check if file exists
        unless File.exist?(model_file_path)
          log_step "Skipping #{model_name}: Model file not found at #{model_file_path}", :warning
          return
        end

        # Check if TenantScoped is already included
        model_content = File.read(model_file_path)
        if model_content.match?(/^\s*include\s+TenantScoped\b/)
          log_step "Skipping #{model_name}: TenantScoped already included", :info
          return
        end

        log_step "Adding TenantScoped concern to #{model_name}", :info

        # Use Rails generator methods to inject the concern
        # Try inject_into_class first (more reliable)
        begin
          inject_into_class model_file_path, model_name do
            "  include TenantScoped\n"
          end
          log_step "✓ Added TenantScoped to #{model_name} using inject_into_class", :success
        rescue Thor::Error => e
          # Fallback to inject_into_file if inject_into_class fails
          log_step "inject_into_class failed for #{model_name}, trying fallback method: #{e.message}", :warning

          # Find the class declaration line and inject after it
          class_pattern = /^(\s*)class\s+#{Regexp.escape(model_name)}\b.*$/

          if model_content.match?(class_pattern)
            inject_into_file model_file_path, after: class_pattern do
              "\n  include TenantScoped\n"
            end
            log_step "✓ Added TenantScoped to #{model_name} using inject_into_file", :success
          else
            log_step "Could not find class declaration for #{model_name} in #{model_file_path}", :error
            return
          end
        end
      rescue => e
        log_step "Error updating #{model_name}: #{e.message}", :error
      end

      # Generate a single migration for adding organization_id to a specific model
      def generate_tenant_migration_for_model(model_result)
        model_class = model_result[:model]
        model_name = model_result[:name]
        table_name = model_result[:table_name]

        # Set up template variables
        @target_table_name = table_name
        @migration_version = get_rails_migration_version

        # Generate migration name using proper string manipulation
        tenant_column_camelized = @tenant_column.split('_').map(&:capitalize).join
        model_name_pluralized = model_name + 's'  # Simple pluralization
        migration_class_name = "Add#{tenant_column_camelized}To#{model_name_pluralized}"

        log_step "Generating migration: #{migration_class_name}", :info

        # Generate unique timestamp to avoid conflicts
        @migration_counter ||= 0
        @migration_counter += 1
        adjusted_timestamp = (Time.current + @migration_counter.seconds).strftime("%Y%m%d%H%M%S")

        migration_filename = "#{adjusted_timestamp}_#{migration_class_name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase}.rb"
        migration_path = "db/migrate/#{migration_filename}"

        # Use Rails migration template
        template "migration_templates/add_organization_id_to_table.rb.erb", migration_path

        log_step "✓ Created migration: #{migration_path}", :success
      end

      # Get the appropriate Rails migration version
      def get_rails_migration_version
        if defined?(Rails) && Rails.respond_to?(:version)
          # Extract major.minor version from Rails version
          major, minor = Rails.version.split('.').first(2).map(&:to_i)
          "#{major}.#{minor}"
        else
          # Fallback to a reasonable default
          "7.0"
        end
      end

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

      # Handle models without corresponding database tables gracefully
      def handle_models_without_tables
        return unless @models_without_tables&.any?

        log_section "HANDLING MODELS WITHOUT DATABASE TABLES"
        log_step "Found #{@models_without_tables.count} model(s) without corresponding database tables", :warning

        @models_without_tables.each do |model_result|
          handle_model_without_table(model_result)
        end

        log_step "✓ Processed #{@models_without_tables.count} model(s) without tables", :info
      end

      # Handle a single model without a database table
      def handle_model_without_table(model_result)
        model_class = model_result[:model]
        model_name = model_result[:name]

        log_step "Analyzing #{model_name}:", :info

        # Check if this is a concern, service object, or other non-persistent model
        model_type = determine_model_type(model_class)

        case model_type
        when :concern
          say "  • #{model_name} appears to be a concern - no action needed", :green
        when :service_object
          say "  • #{model_name} appears to be a service object - no action needed", :green
        when :form_object
          say "  • #{model_name} appears to be a form object - no action needed", :green
        when :decorator
          say "  • #{model_name} appears to be a decorator - no action needed", :green
        when :abstract_model
          say "  • #{model_name} is an abstract model - no action needed", :green
        when :possibly_missing_table
          handle_possibly_missing_table(model_result)
        else
          handle_unknown_tableless_model(model_result)
        end
      end

      # Determine the type of a model without a table
      def determine_model_type(model_class)
        model_name = model_class.name

        # Check if it's an abstract class
        return :abstract_model if model_class.abstract_class?

        # Check for concern patterns (including -able suffix pattern)
        if model_name.end_with?('Concern') ||
           model_class.ancestors.include?(ActiveSupport::Concern) ||
           model_class.included_modules.any? { |mod| mod.name == 'ActiveSupport::Concern' } ||
           (model_name.match?(/^[A-Z][a-z]*able$/) && !model_name.end_with?('Table'))
          return :concern
        end

        # Check for service object patterns
        if model_name.end_with?('Service') ||
           model_name.end_with?('Handler') ||
           model_name.end_with?('Command') ||
           model_name.end_with?('Query')
          return :service_object
        end

        # Check for form object patterns
        if model_name.end_with?('Form') ||
           model_name.end_with?('FormObject') ||
           model_class.ancestors.any? { |ancestor| ancestor.name&.include?('Form') }
          return :form_object
        end

        # Check for decorator patterns
        if model_name.end_with?('Decorator') ||
           model_name.end_with?('Presenter') ||
           model_class.ancestors.any? { |ancestor| ancestor.name&.include?('Decorator') }
          return :decorator
        end

        # If it inherits from ApplicationRecord but has no table, it might be missing a migration
        # Only classify as possibly_missing_table if it looks like a typical Rails model name
        if model_class < ApplicationRecord &&
           model_name.match?(/^[A-Z][a-zA-Z]*$/) &&
           !model_name.match?(/^[A-Z][a-z]*able$/) && # Not a concern-like name
           !model_name.include?('Class') # Generic class names are unlikely to be models
          return :possibly_missing_table
        end

        :unknown
      end

      # Handle a model that might be missing its database table
      def handle_possibly_missing_table(model_result)
        model_name = model_result[:name]

        say "  • #{model_name} inherits from ApplicationRecord but has no table", :red
        say "    Possible actions:", :cyan
        say "    - Create missing migration: `bin/rails generate migration Create#{model_name.pluralize}`", :cyan
        say "    - Move to app/lib if it's not meant to be a persistent model", :cyan
        say "    - Delete the file if it's no longer needed", :cyan

        # Store this model for potential migration generation
        @models_missing_tables ||= []
        @models_missing_tables << model_result
      end

      # Handle models of unknown type without tables
      def handle_unknown_tableless_model(model_result)
        model_name = model_result[:name]

        say "  • #{model_name} - unclear model type without database table", :yellow
        say "    Recommendations:", :cyan
        say "    - Review if this model should have a database table", :cyan
        say "    - Consider moving to app/lib if it's a utility class", :cyan
        say "    - Consider making it an abstract class if it's meant to be inherited", :cyan
        say "    - Add table_name = nil if it's intentionally tableless", :cyan
      end

      # Offer to generate migrations for models that appear to be missing tables
      def offer_missing_table_migrations
        return unless @models_missing_tables&.any?

        log_section "MISSING TABLE MIGRATIONS"

        say "The following models appear to be missing database tables:", :warning
        @models_missing_tables.each do |model_result|
          say "  • #{model_result[:name]}", :red
        end

        if yes?("\nWould you like to generate basic migrations for these models? (y/n)")
          @models_missing_tables.each do |model_result|
            generate_basic_table_migration(model_result)
          end
        else
          say "Skipping migration generation. You can manually create these later.", :info
        end
      end

      # Generate a basic table migration for a model missing its table
      def generate_basic_table_migration(model_result)
        model_name = model_result[:name]
        table_name = model_name.underscore.pluralize

        log_step "Generating basic migration for #{model_name}", :info

        # Generate a basic create table migration
        migration_class_name = "Create#{model_name.pluralize}"

        # Generate unique timestamp to avoid conflicts
        @migration_counter ||= 0
        @migration_counter += 1
        adjusted_timestamp = (Time.current + @migration_counter.seconds).strftime("%Y%m%d%H%M%S")

        migration_filename = "#{adjusted_timestamp}_#{migration_class_name.underscore}.rb"
        migration_path = "db/migrate/#{migration_filename}"

        # Create basic migration content
        migration_content = generate_basic_migration_content(table_name, model_name)

        create_file migration_path, migration_content

        log_step "✓ Created basic migration: #{migration_path}", :success
        say "    Remember to customize the migration with appropriate columns!", :yellow
      end

      # Generate basic migration content for a missing table
      def generate_basic_migration_content(table_name, model_name)
        migration_version = get_rails_migration_version

        <<~RUBY
          class Create#{model_name.pluralize} < ActiveRecord::Migration[#{migration_version}]
            def change
              create_table :#{table_name} do |t|
                # TODO: Add your columns here
                # Example columns:
                # t.string :name, null: false
                # t.text :description

                # Add organization_id for tenant scoping
                t.references :organization, null: false, foreign_key: true, index: true

                t.timestamps
              end

              # Add indexes as needed
              # add_index :#{table_name}, :some_column
            end
          end
        RUBY
      end

      # Update existing model associations to work with tenant scoping
      def update_existing_model_associations
        return unless (@models_needing_org_id&.any? || @models_already_compatible&.any?)

        log_section "UPDATING MODEL ASSOCIATIONS FOR TENANT SCOPING"
        log_step "Analyzing and updating model associations to be tenant-aware...", :info

        models_to_update = (@models_needing_org_id || []) + (@models_already_compatible || [])
        associations_updated = 0

        models_to_update.each do |model_result|
          updated_count = update_model_associations(model_result)
          associations_updated += updated_count
        end

        if associations_updated > 0
          log_step "✓ Updated #{associations_updated} association(s) across #{models_to_update.count} model(s)", :success
          log_step "Review the updated associations to ensure they meet your requirements", :info
        else
          log_step "No associations required updating", :info
        end
      end

      # Update associations for a specific model
      def update_model_associations(model_result)
        model_class = model_result[:model]
        model_name = model_result[:name]
        model_file_path = "app/models/#{model_name.underscore}.rb"

        return 0 unless File.exist?(model_file_path)

        log_step "Analyzing associations in #{model_name}...", :info

        # Read the model file
        model_content = File.read(model_file_path)
        original_content = model_content.dup

        # Find associations that need tenant scoping
        associations_to_update = find_associations_needing_tenant_scoping(model_content, model_class)

        if associations_to_update.empty?
          log_step "  No associations need updating in #{model_name}", :info
          return 0
        end

        # Update each association
        associations_to_update.each do |association_info|
          model_content = update_association_for_tenant_scoping(model_content, association_info)
        end

        # Write back if there were changes
        if model_content != original_content
          File.write(model_file_path, model_content)
          log_step "  ✓ Updated #{associations_to_update.count} association(s) in #{model_name}", :success

          associations_to_update.each do |assoc|
            log_step "    - #{assoc[:type]} :#{assoc[:name]} (added tenant scoping)", :info
          end

          return associations_to_update.count
        end

        0
      end

      # Find associations that need tenant scoping updates
      def find_associations_needing_tenant_scoping(model_content, model_class)
        associations = []

        # Look for has_many associations
        model_content.scan(/^\s*(has_many\s+:(\w+)(?:,\s*(.*))?)\s*$/) do |full_match, assoc_name, options|
          next if full_match.include?('->') || full_match.include?('lambda') # Skip if already scoped

          # Check if the associated model would be tenant scoped
          associated_model = get_associated_model_class(assoc_name, options, model_class)
          if associated_model && should_add_tenant_scoping_to_association?(associated_model, options)
            associations << {
              type: 'has_many',
              name: assoc_name,
              original_line: full_match,
              associated_model: associated_model,
              options: options
            }
          end
        end

        # Look for has_one associations
        model_content.scan(/^\s*(has_one\s+:(\w+)(?:,\s*(.*))?)\s*$/) do |full_match, assoc_name, options|
          next if full_match.include?('->') || full_match.include?('lambda') # Skip if already scoped

          # Check if the associated model would be tenant scoped
          associated_model = get_associated_model_class(assoc_name, options, model_class)
          if associated_model && should_add_tenant_scoping_to_association?(associated_model, options)
            associations << {
              type: 'has_one',
              name: assoc_name,
              original_line: full_match,
              associated_model: associated_model,
              options: options
            }
          end
        end

        # Look for belongs_to associations that might need scoping through a join model
        model_content.scan(/^\s*(belongs_to\s+:(\w+)(?:,\s*(.*))?)\s*$/) do |full_match, assoc_name, options|
          next if full_match.include?('->') || full_match.include?('lambda') # Skip if already scoped
          next if assoc_name == @organization_name.underscore # Skip organization association

          # Check if this belongs_to might need scoping (for polymorphic or special cases)
          associated_model = get_associated_model_class(assoc_name, options, model_class)
          if associated_model && should_add_tenant_scoping_to_association?(associated_model, options) &&
             options&.include?('polymorphic')
            associations << {
              type: 'belongs_to',
              name: assoc_name,
              original_line: full_match,
              associated_model: associated_model,
              options: options
            }
          end
        end

        associations
      end

      # Get the associated model class for an association
      def get_associated_model_class(association_name, options, current_model_class)
        begin
          # Try to determine the class name from options or association name
          class_name = nil

          if options && options.include?('class_name')
            # Extract class_name from options
            class_name_match = options.match(/class_name:\s*['"]([^'"]+)['"]/)
            class_name = class_name_match[1] if class_name_match
          end

          if options && options.include?('through')
            # For through associations, we need to check the ultimate target
            through_match = options.match(/through:\s*:(\w+)/)
            if through_match
              through_association = through_match[1]
              # This is complex to resolve properly, so we'll be conservative
              return nil
            end
          end

          # Default to inferring from association name
          class_name ||= association_name.to_s.classify.singularize

          # Try to constantize the class
          Object.const_get(class_name)
        rescue NameError
          # Model doesn't exist or isn't loaded
          nil
        end
      end

      # Determine if an association should have tenant scoping added
      def should_add_tenant_scoping_to_association?(associated_model, options)
        return false unless associated_model
        return false if should_exclude_model?(associated_model)

        # Check if the associated model has or will have organization_id
        has_org_id = associated_model.column_names.include?(@tenant_column) rescue false
        will_have_org_id = @models_needing_org_id&.any? { |m| m[:model] == associated_model } || false

        has_org_id || will_have_org_id
      end

      # Update an association to include tenant scoping
      def update_association_for_tenant_scoping(model_content, association_info)
        original_line = association_info[:original_line]
        association_type = association_info[:type]
        association_name = association_info[:name]

        # Build the scoped version of the association
        scoped_association = case association_type
        when 'has_many'
          build_scoped_has_many_association(association_info)
        when 'has_one'
          build_scoped_has_one_association(association_info)
        when 'belongs_to'
          build_scoped_belongs_to_association(association_info)
        else
          original_line # Fallback
        end

        # Add comment explaining the change
        comment = "  # Tenant-scoped association: only returns #{association_name} within the current organization"
        scoped_with_comment = "#{comment}\n  #{scoped_association}"

        # Replace the original association
        model_content.gsub(/^\s*#{Regexp.escape(original_line)}.*$/, scoped_with_comment)
      end

      # Build a tenant-scoped has_many association
      def build_scoped_has_many_association(association_info)
        name = association_info[:name]
        options = association_info[:options]

        # Build the scope part
        scope_lambda = "-> { where(#{@tenant_column}: current_#{@organization_name.underscore}_id) }"

        if options && !options.empty?
          # Add scope to existing options
          "has_many :#{name}, #{scope_lambda}, #{options}"
        else
          # Just add the scope
          "has_many :#{name}, #{scope_lambda}"
        end
      end

      # Build a tenant-scoped has_one association
      def build_scoped_has_one_association(association_info)
        name = association_info[:name]
        options = association_info[:options]

        # Build the scope part
        scope_lambda = "-> { where(#{@tenant_column}: current_#{@organization_name.underscore}_id) }"

        if options && !options.empty?
          # Add scope to existing options
          "has_one :#{name}, #{scope_lambda}, #{options}"
        else
          # Just add the scope
          "has_one :#{name}, #{scope_lambda}"
        end
      end

      # Build a tenant-scoped belongs_to association (for polymorphic cases)
      def build_scoped_belongs_to_association(association_info)
        name = association_info[:name]
        options = association_info[:options]

        # For polymorphic belongs_to, we add a validation instead of a scope
        # The scope would be added to the polymorphic target models instead
        "belongs_to :#{name}#{options ? ", #{options}" : ''}"
      end
    end
  end
end
