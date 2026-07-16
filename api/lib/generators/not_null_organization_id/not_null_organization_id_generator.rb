# frozen_string_literal: true

class NotNullOrganizationIdGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  desc "This generator creates the migrations to add the not null constraint on the organization_id column of a database table"

  def self.next_migration_number(dirname)
    next_migration_number = current_migration_number(dirname) + 1
    ActiveRecord::Migration.next_migration_number(next_migration_number)
  end

  def create_migrations
    migration_template "organization_id_check_constaint.rb.erb", "db/migrate/organization_id_check_constaint_on_#{file_name}.rb"
    migration_template "not_null_organization_id.rb.erb", "db/migrate/not_null_organization_id_on_#{file_name}.rb"
  end
end
