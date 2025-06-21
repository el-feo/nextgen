# frozen_string_literal: true

require "test_helper"

class MultiTenancyModelsTest < Minitest::Test
  def setup
    # We'll test the model templates by examining their content and structure
    @template_dir = File.expand_path("../../../../lib/nextgen/generators/multi_tenancy", __dir__)
  end

  # Test template file existence and basic structure
  def test_organization_template_exists_and_valid
    template_path = File.join(@template_dir, "organization.rb.erb")
    assert File.exist?(template_path), "Organization template should exist"

    content = File.read(template_path)

    # Test for key components in the template
    assert_includes content, "class <%= @organization_name %>", "Should use organization_name variable"
    assert_includes content, "< ApplicationRecord", "Should inherit from ApplicationRecord"
    assert_includes content, "has_many :memberships", "Should define memberships association"
    assert_includes content, "has_many :users, through: :memberships", "Should define users association"
    assert_includes content, "validates :name, presence: true", "Should validate name presence"
    assert_includes content, "scope :active", "Should define active scope"
    assert_includes content, "def display_name", "Should define display_name method"
    assert_includes content, "def archive!", "Should define archive! method"
    assert_includes content, "before_validation :strip_whitespace", "Should define callbacks"
  end

  def test_role_template_exists_and_valid
    template_path = File.join(@template_dir, "role.rb.erb")
    assert File.exist?(template_path), "Role template should exist"

    content = File.read(template_path)

    # Test for key components in the template
    assert_includes content, "class <%= @role_name %>", "Should use role_name variable"
    assert_includes content, "< ApplicationRecord", "Should inherit from ApplicationRecord"
    assert_includes content, "has_many :memberships", "Should define memberships association"
    assert_includes content, "enum :role_type", "Should define role_type enum"
    assert_includes content, 'member: "member"', "Should define member role"
    assert_includes content, 'admin: "admin"', "Should define admin role"
    assert_includes content, 'owner: "owner"', "Should define owner role"
    assert_includes content, "validates :name", "Should validate name"
    assert_includes content, "validates :role_type", "Should validate role_type"
    assert_includes content, "def admin?", "Should define admin? method"
    assert_includes content, "def can_manage_users?", "Should define permission methods"
    assert_includes content, "scope :by_type", "Should define scopes"
  end

  def test_membership_template_exists_and_valid
    template_path = File.join(@template_dir, "membership.rb.erb")
    assert File.exist?(template_path), "Membership template should exist"

    content = File.read(template_path)

    # Test for key components in the template
    assert_includes content, "class <%= @membership_name %>", "Should use membership_name variable"
    assert_includes content, "< ApplicationRecord", "Should inherit from ApplicationRecord"
    assert_includes content, "belongs_to :user", "Should define user association"
    assert_includes content, "belongs_to :<%= @organization_name.underscore %>", "Should define organization association"
    assert_includes content, "belongs_to :<%= @role_name.underscore %>", "Should define role association"
    assert_includes content, "validates :user_id", "Should validate user_id"
    assert_includes content, "uniqueness:", "Should define uniqueness validations"
    assert_includes content, "scope :active", "Should define scopes"
    assert_includes content, "def admin?", "Should define role checking methods"
    assert_includes content, "delegate :name, to: :user", "Should define delegations"
    assert_includes content, "before_save :set_defaults", "Should define callbacks"
    assert_includes content, "before_destroy :ensure_not_last_owner", "Should prevent last owner deletion"
  end

  # Test template content for proper ERB structure
  def test_organization_template_erb_structure
    template_path = File.join(@template_dir, "organization.rb.erb")
    content = File.read(template_path)

    # Count ERB tags to ensure they're balanced
    open_tags = content.scan(/<%=?/).count
    close_tags = content.scan(/%>/).count
    assert_equal open_tags, close_tags, "ERB tags should be balanced"

    # Ensure no hardcoded class names in wrong places
    refute_includes content, "class Organization", "Should not hardcode Organization class name"
    refute_includes content, "class Role", "Should not hardcode Role class name"
    refute_includes content, "class Membership", "Should not hardcode Membership class name"
  end

  def test_role_template_erb_structure
    template_path = File.join(@template_dir, "role.rb.erb")
    content = File.read(template_path)

    # Count ERB tags to ensure they're balanced
    open_tags = content.scan(/<%=?/).count
    close_tags = content.scan(/%>/).count
    assert_equal open_tags, close_tags, "ERB tags should be balanced"

    # Check for module namespacing wrapper
    assert_includes content, "<% module_namespacing do -%>", "Should use module namespacing"
    assert_includes content, "<% end -%>", "Should close module namespacing"
  end

  def test_membership_template_erb_structure
    template_path = File.join(@template_dir, "membership.rb.erb")
    content = File.read(template_path)

    # Count ERB tags to ensure they're balanced
    open_tags = content.scan(/<%=?/).count
    close_tags = content.scan(/%>/).count
    assert_equal open_tags, close_tags, "ERB tags should be balanced"

    # Check for module namespacing wrapper
    assert_includes content, "<% module_namespacing do -%>", "Should use module namespacing"
    assert_includes content, "<% end -%>", "Should close module namespacing"

    # Check for proper variable usage
    assert_includes content, "<%= @organization_name.underscore %>", "Should use organization underscore"
    assert_includes content, "<%= @role_name.underscore %>", "Should use role underscore"
  end

  # Test business logic in templates
  def test_organization_template_business_logic
    template_path = File.join(@template_dir, "organization.rb.erb")
    content = File.read(template_path)

    # Test validation logic
    assert_includes content, "length: { minimum: 2, maximum: 100 }", "Should validate name length"
    assert_includes content, "uniqueness: { case_sensitive: false }", "Should validate uniqueness case insensitive"

    # Test callback logic
    assert_includes content, "before_validation :strip_whitespace", "Should strip whitespace"
    assert_includes content, "before_save :normalize_name", "Should normalize name"

    # Test instance methods
    assert_includes content, "def user_count", "Should define user_count method"
    assert_includes content, 'name.presence || "Unnamed Organization"', "Should handle blank names"
    assert_includes content, "update!(archived: true)", "Should implement archive!"
  end

  def test_role_template_business_logic
    template_path = File.join(@template_dir, "role.rb.erb")
    content = File.read(template_path)

    # Test enum configuration
    assert_includes content, "prefix: true", "Should use enum prefix"
    assert_includes content, "validate: true", "Should validate enum"

    # Test role hierarchy logic
    assert_includes content, "role_type_admin? || role_type_owner?", "Should define admin? correctly"
    assert_includes content, "def can_manage_organization?", "Should define management capabilities"
    assert_includes content, "role_type_owner?", "Should check for owner role"

    # Test validation logic
    assert_includes content, "def validate_role_hierarchy", "Should validate role hierarchy"
    assert_includes content, "last owner role", "Should prevent removing last owner"
  end

  def test_membership_template_business_logic
    template_path = File.join(@template_dir, "membership.rb.erb")
    content = File.read(template_path)

    # Test uniqueness constraints
    assert_includes content, "already has a membership in this organization", "Should prevent duplicate memberships"
    assert_includes content, "can only have one role per organization", "Should enforce single role per org"

    # Test capability delegation
    assert_includes content, "def admin?", "Should delegate admin check to role"
    assert_includes content, "def can_manage_membership?(target_membership)", "Should handle membership management"
    assert_includes content, "return false if target_membership == self", "Should prevent self-management"

    # Test safety mechanisms
    assert_includes content, "def ensure_not_last_owner", "Should prevent last owner deletion"
    assert_includes content, "Cannot remove the last owner", "Should have clear error message"
    assert_includes content, "throw(:abort)", "Should abort deletion properly"
  end

  # Test template integration points
  def test_templates_use_consistent_variable_names
    org_content = File.read(File.join(@template_dir, "organization.rb.erb"))
    role_content = File.read(File.join(@template_dir, "role.rb.erb"))
    membership_content = File.read(File.join(@template_dir, "membership.rb.erb"))

    # All templates should use consistent variable naming
    assert_includes org_content, "@organization_name", "Organization template should use @organization_name"
    assert_includes role_content, "@role_name", "Role template should use @role_name"
    assert_includes membership_content, "@membership_name", "Membership template should use @membership_name"

    # Membership template should reference other model names
    assert_includes membership_content, "@organization_name.underscore", "Membership should reference organization"
    assert_includes membership_content, "@role_name.underscore", "Membership should reference role"
  end

  def test_templates_define_required_associations
    role_content = File.read(File.join(@template_dir, "role.rb.erb"))
    membership_content = File.read(File.join(@template_dir, "membership.rb.erb"))

    # Test that role properly destroys dependent memberships
    assert_includes role_content, "dependent: :destroy", "Role should destroy memberships"

    # Test that membership properly references the other models
    assert_includes membership_content, "inverse_of: :memberships", "Should define inverse associations"

    # Test scope definitions that use joins
    assert_includes membership_content, "joins(:<%= @role_name.underscore %>)", "Should join with role table"
    assert_includes membership_content, "where(<%= @role_name.underscore.pluralize %>:", "Should reference role table"
  end

  def test_templates_include_proper_error_handling
    role_content = File.read(File.join(@template_dir, "role.rb.erb"))
    membership_content = File.read(File.join(@template_dir, "membership.rb.erb"))

    # Test error handling in role hierarchy validation
    assert_includes role_content, "errors.add(:role_type", "Should add role_type errors"
    assert_includes role_content, "cannot be changed", "Should have descriptive error messages"

    # Test error handling in membership validation
    assert_includes membership_content, "errors.add(:base", "Should add base errors for business logic"
    assert_includes membership_content, "Cannot remove the last owner", "Should have clear error messages"
  end
end
