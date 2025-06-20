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
        log_step "Checking Rails compatibility...", :info

        unless rails_version_compatible?
          log_step "This generator requires Rails 6.0 or higher. Current version: #{Rails.version}", :error
          exit(1)
        end

        log_step "Rails #{Rails.version} detected", :success

        @test_framework = detect_test_framework
        log_step "Test framework: #{@test_framework}", :success
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
