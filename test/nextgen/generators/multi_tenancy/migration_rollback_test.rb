# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MultiTenancyMigrationRollbackTest < Minitest::Test
  def setup
    @organization_name = "Organization"
    @role_name = "Role"
    @membership_name = "Membership"
    @tenant_column = "organization_id"
    @target_table_name = "users"
    @migration_version = "7.0"

    # Create temporary directory for migration files
    @temp_dir = Dir.mktmpdir("migration_rollback_test")
    @migration_templates_dir = File.join(
      Dir.pwd, "lib", "nextgen", "generators", "multi_tenancy", "migration_templates"
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_create_organizations_migration_rollback_structure
    template_path = File.join(@migration_templates_dir, "create_organizations.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify change method exists (Rails can auto-reverse)
    assert_match(/def change/, rendered_migration)
    refute_match(/def up/, rendered_migration)
    refute_match(/def down/, rendered_migration)

    # Verify table creation (reversible by Rails)
    assert_match(/create_table :organizations/, rendered_migration)

    # Verify indexes (reversible by Rails)
    assert_match(/add_index :organizations, :name/, rendered_migration)
    assert_match(/add_index :organizations, :active/, rendered_migration)
    assert_match(/add_index :organizations, :slug, unique: true/, rendered_migration)

    # Verify reversible block for complex operations
    assert_match(/reversible do \|direction\|/, rendered_migration)
    assert_match(/direction\.up do/, rendered_migration)
    assert_match(/direction\.down do/, rendered_migration)

    # Verify PostgreSQL constraints have proper rollback
    assert_match(/DROP CONSTRAINT IF EXISTS check_organizations_name_length/, rendered_migration)
    assert_match(/DROP CONSTRAINT IF EXISTS check_organizations_slug_format/, rendered_migration)
  end

  def test_create_roles_migration_rollback_structure
    template_path = File.join(@migration_templates_dir, "create_roles.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify change method (auto-reversible)
    assert_match(/def change/, rendered_migration)

    # Verify table creation and indexes (auto-reversible)
    assert_match(/create_table :roles/, rendered_migration)
    assert_match(/add_index :roles, :role_type/, rendered_migration)
    assert_match(/add_index :roles, \[:name, :role_type\], unique: true/, rendered_migration)

    # Verify data seeding with reversible block
    assert_match(/reversible do \|dir\|/, rendered_migration)
    assert_match(/dir\.up do/, rendered_migration)
    assert_match(/dir\.down do/, rendered_migration)

    # Verify default roles creation in up block
    assert_match(/Role\.create!\(\[/, rendered_migration)

    # Verify down block handles data cleanup (comment suggests drop_table handles it)
    assert_match(/# Remove default roles \(will be handled by drop_table\)/, rendered_migration)
  end

  def test_create_memberships_migration_rollback_structure
    template_path = File.join(@migration_templates_dir, "create_memberships.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify change method (auto-reversible)
    assert_match(/def change/, rendered_migration)

    # Verify table creation with foreign keys (auto-reversible)
    assert_match(/create_table :memberships/, rendered_migration)
    assert_match(/t\.belongs_to :user, null: false, foreign_key: true, index: true/, rendered_migration)
    assert_match(/t\.belongs_to :organization, null: false, foreign_key: true, index: true/, rendered_migration)
    assert_match(/t\.belongs_to :role, null: false, foreign_key: true, index: true/, rendered_migration)

    # Verify composite indexes (auto-reversible)
    assert_match(/add_index :memberships,\s+\[:user_id, :organization_id\],\s+unique: true/m, rendered_migration)

    # Verify foreign key constraints documentation
    assert_match(/# Ensure referential integrity with foreign key constraints/, rendered_migration)
    assert_match(/# These are automatically added by `foreign_key: true`/, rendered_migration)
  end

  def test_add_organization_id_migration_rollback_structure
    template_path = File.join(@migration_templates_dir, "add_organization_id_to_table.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify change method (auto-reversible)
    assert_match(/def change/, rendered_migration)

    # Verify add_reference with foreign key (auto-reversible)
    assert_match(/add_reference :users, :organization, null: false, foreign_key: true, index: true/, rendered_migration)

    # Verify column comment (auto-reversible)
    assert_match(/change_column_comment :users, :organization_id/, rendered_migration)

    # Verify migration class name generation
    assert_match(/class AddOrganizationIdToUsers < ActiveRecord::Migration/, rendered_migration)
  end

  def test_migration_rollback_simulation_organizations
    # Simulate the rollback behavior by checking what operations would be reversed
    template_path = File.join(@migration_templates_dir, "create_organizations.rb.erb")
    rendered_migration = render_migration_template(template_path)

    reversible_operations = [
      "create_table :organizations",      # Rails auto-reverses to drop_table
      "add_index :organizations, :name",  # Rails auto-reverses to remove_index
      "add_index :organizations, :active", # Rails auto-reverses to remove_index
      "add_index :organizations, :slug",  # Rails auto-reverses to remove_index
    ]

    reversible_operations.each do |operation|
      assert_match(/#{Regexp.escape(operation)}/, rendered_migration,
        "Migration should contain reversible operation: #{operation}")
    end

    # Verify explicit down operations for PostgreSQL constraints
    postgresql_down_operations = [
      "DROP CONSTRAINT IF EXISTS check_organizations_name_length",
      "DROP CONSTRAINT IF EXISTS check_organizations_slug_format"
    ]

    postgresql_down_operations.each do |operation|
      assert_match(/#{Regexp.escape(operation)}/, rendered_migration,
        "Migration should explicitly handle PostgreSQL constraint removal: #{operation}")
    end
  end

  def test_migration_rollback_simulation_roles_with_data
    template_path = File.join(@migration_templates_dir, "create_roles.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify data seeding is properly handled in reversible block
    assert_match(/dir\.up do/, rendered_migration)
    assert_match(/Role\.create!\(\[/, rendered_migration)

    # Verify down block exists (even if it's just a comment)
    assert_match(/dir\.down do/, rendered_migration)

    # The down block should either explicitly remove data or rely on drop_table
    # In this case, it's documented that drop_table will handle the cleanup
    assert_match(/# Remove default roles/, rendered_migration)
  end

  def test_foreign_key_rollback_behavior
    template_path = File.join(@migration_templates_dir, "create_memberships.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify foreign keys are created with proper syntax for auto-rollback
    foreign_key_patterns = [
      /t\.belongs_to :user.*foreign_key: true/,
      /t\.belongs_to :organization.*foreign_key: true/,
      /t\.belongs_to :role.*foreign_key: true/
    ]

    foreign_key_patterns.each do |pattern|
      assert_match(pattern, rendered_migration,
        "Migration should create foreign key with auto-rollback syntax: #{pattern}")
    end
  end

  def test_index_rollback_behavior
    template_path = File.join(@migration_templates_dir, "create_organizations.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Test different types of indexes that should be auto-reversible
    index_patterns = [
      /add_index :organizations, :name$/,                    # Simple index
      /add_index :organizations, :active$/,                  # Simple index
      /add_index :organizations, :slug, unique: true/,       # Unique index
      /add_index :organizations, \[:active, :name\]/,        # Composite index
      /add_index :organizations,\s+"LOWER\(name\)",\s+unique: true/m  # Expression index (multiline)
    ]

    index_patterns.each do |pattern|
      assert_match(pattern, rendered_migration,
        "Migration should create reversible index: #{pattern}")
    end
  end

  def test_reference_column_rollback_behavior
    template_path = File.join(@migration_templates_dir, "add_organization_id_to_table.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify add_reference can be auto-reversed to remove_reference
    assert_match(/add_reference :users, :organization/, rendered_migration)
    assert_match(/null: false/, rendered_migration)
    assert_match(/foreign_key: true/, rendered_migration)
    assert_match(/index: true/, rendered_migration)

    # When rolled back, Rails will:
    # 1. Remove the foreign key constraint
    # 2. Remove the index
    # 3. Remove the column
  end

  def test_migration_version_compatibility
    # Test that migrations work with different Rails versions
    old_version_migration = render_migration_template(
      File.join(@migration_templates_dir, "create_organizations.rb.erb"),
      migration_version: "5.2"
    )

    new_version_migration = render_migration_template(
      File.join(@migration_templates_dir, "create_organizations.rb.erb"),
      migration_version: "7.0"
    )

    # Both should have proper migration inheritance
    assert_match(/< ActiveRecord::Migration\[5\.2\]/, old_version_migration)
    assert_match(/< ActiveRecord::Migration\[7\.0\]/, new_version_migration)

    # Both should be equally rollback-capable
    [:change, :reversible, :create_table, :add_index].each do |method|
      assert_match(/#{method}/, old_version_migration)
      assert_match(/#{method}/, new_version_migration)
    end
  end

  def test_rollback_error_handling
    template_path = File.join(@migration_templates_dir, "create_organizations.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify PostgreSQL-specific operations check adapter
    assert_match(/if connection\.adapter_name == 'PostgreSQL'/, rendered_migration)

    # Verify constraints use IF EXISTS for safe rollback
    assert_match(/DROP CONSTRAINT IF EXISTS/, rendered_migration)

    # This prevents errors during rollback if constraints don't exist
  end

  def test_complex_rollback_scenario_simulation
    # Test a complex scenario where multiple migrations would be rolled back
    migrations = [
      "create_organizations.rb.erb",
      "create_roles.rb.erb",
      "create_memberships.rb.erb",
      "add_organization_id_to_table.rb.erb"
    ]

    rendered_migrations = migrations.map do |migration_file|
      render_migration_template(File.join(@migration_templates_dir, migration_file))
    end

    # Verify rollback order considerations:
    # 1. add_organization_id_to_table should rollback first (removes FK references)
    # 2. create_memberships should rollback next (depends on organizations and roles)
    # 3. create_roles and create_organizations can rollback in any order

    # Check that foreign key dependencies are properly structured
    memberships_migration = rendered_migrations[2]
    add_org_id_migration = rendered_migrations[3]

    # Memberships references organizations and roles
    assert_match(/foreign_key: true/, memberships_migration)

    # Add organization ID references organizations
    assert_match(/add_reference :users, :organization.*foreign_key: true/, add_org_id_migration)

    # All migrations use 'change' method for auto-reversibility
    rendered_migrations.each_with_index do |migration, index|
      assert_match(/def change/, migration,
        "Migration #{migrations[index]} should use 'change' method for auto-reversibility")
    end
  end

  def test_data_integrity_during_rollback
    template_path = File.join(@migration_templates_dir, "create_roles.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Verify that data operations are in reversible blocks
    assert_match(/reversible do \|dir\|/, rendered_migration)

    # Data creation should be in up block
    assert_match(/dir\.up do.*Role\.create!/m, rendered_migration)

    # Down block should handle data cleanup appropriately
    assert_match(/dir\.down do/, rendered_migration)

    # The comment indicates that drop_table will handle cleanup,
    # which is appropriate because dropping the table removes all data
    assert_match(/will be handled by drop_table/, rendered_migration)
  end

  def test_rollback_performance_considerations
    # Test that migrations are structured for efficient rollback
    template_path = File.join(@migration_templates_dir, "create_organizations.rb.erb")
    rendered_migration = render_migration_template(template_path)

    # Indexes should be created in the same transaction as table for efficiency
    table_and_indexes = rendered_migration.scan(/(?:create_table|add_index)/).length
    assert(table_and_indexes >= 4, "Should create table and multiple indexes")

    # PostgreSQL constraints should be in reversible blocks to avoid transaction issues
    assert_match(/reversible do.*direction\.up.*execute.*direction\.down.*execute/m, rendered_migration)
  end

  private

  def render_migration_template(template_path, migration_version: @migration_version)
    template_content = File.read(template_path)

    # Replace Rails::VERSION with hardcoded values for testing
    # This allows us to focus on testing rollback capabilities rather than ERB rendering issues
    test_content = template_content.gsub(
      /<% migration_version = Rails::VERSION::MAJOR >= 5 \? "\[#\{Rails::VERSION::MAJOR\}\.#\{Rails::VERSION::MINOR\}\]" : "" -%>/,
      "<% migration_version = \"[#{migration_version}]\" -%>"
    )

    # Create ERB binding with instance variables
    binding_context = create_binding_context(migration_version)

    # Render the ERB template
    ERB.new(test_content, trim_mode: '-').result(binding_context)
  end

  def create_binding_context(migration_version)
    # Create a simple binding context with instance variables (no Rails constant needed now)
    context = Object.new

    context.instance_variable_set(:@organization_name, @organization_name)
    context.instance_variable_set(:@role_name, @role_name)
    context.instance_variable_set(:@membership_name, @membership_name)
    context.instance_variable_set(:@tenant_column, @tenant_column)
    context.instance_variable_set(:@target_table_name, @target_table_name)
    context.instance_variable_set(:@migration_version, migration_version)

    # Create a custom binding by creating a method on the context object
    def context.get_binding
      binding
    end

    context.get_binding
  end
end
