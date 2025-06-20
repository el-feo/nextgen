# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module Nextgen
  module Generators
    class MultiTenancyGenerator < Rails::Generators::Base
      desc "Add multi-tenancy support to your Rails application with organizations, roles, and tenant scoping"

      def self.exit_on_failure?
        true
      end

      # Check for Rails 8 compatibility and detect test framework
      def check_compatibility
        say "Checking Rails compatibility...", :green

        unless rails_version_compatible?
          say "ERROR: This generator requires Rails 6.0 or higher. Current version: #{Rails.version}", :red
          exit(1)
        end

        say "✓ Rails #{Rails.version} detected", :green

        @test_framework = detect_test_framework
        say "✓ Test framework: #{@test_framework}", :green
      end

      # Validate that User model exists
      def validate_user_model
        say "Validating User model...", :green

        unless user_model_exists?
          say <<~ERROR, :red
            ERROR: User model not found!

            This generator requires a User model to exist in your application.
            Please create a User model first:

              rails generate model User name:string email:string
              rails db:migrate

            Then run this generator again.
          ERROR
          exit(1)
        end

        say "✓ User model found", :green
      end

      # Get user confirmation before making changes
      def get_user_confirmation
        say "\nThis generator will:", :yellow
        say "• Create Organization, Role, and Membership models"
        say "• Add migrations for multi-tenancy tables"
        say "• Create a TenantScoped concern for automatic scoping"
        say "• Modify existing models to include organization_id"
        say "• Add foreign key constraints and indexes"

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

      private

      def rails_version_compatible?
        Rails.version >= "6.0"
      end

      def detect_test_framework
        if File.exist?("spec/spec_helper.rb")
          :rspec
        elsif File.exist?("test/test_helper.rb")
          :minitest
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
    end
  end
end
