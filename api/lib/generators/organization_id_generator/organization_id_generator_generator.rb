# frozen_string_literal: true

class OrganizationIdGeneratorGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  desc "This generator creates the migrations and job to add the organization_id column to a database table"

  def self.next_migration_number(dirname)
    next_migration_number = current_migration_number(dirname) + 1
    ActiveRecord::Migration.next_migration_number(next_migration_number)
  end

  def create_migrations
    migration_template "add_organization_id_migration.rb.erb", "db/migrate/add_organization_id_to_#{file_name}.rb"
    migration_template "add_organization_id_fk_migration.rb.erb", "db/migrate/add_organization_id_fk_to_#{file_name}.rb"
    migration_template "validate_organization_foreign_key_migration.rb.erb", "db/migrate/validate_#{file_name}_organizations_foreign_key.rb"
  end

  def create_job
    template "job_template.rb.erb", "app/jobs/database_migrations/populate_#{file_name}_with_organization_job.rb"
  end
end
