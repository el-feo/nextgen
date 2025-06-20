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
    end
  end
end
