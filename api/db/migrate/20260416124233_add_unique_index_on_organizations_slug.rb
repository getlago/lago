# frozen_string_literal: true

class AddUniqueIndexOnOrganizationsSlug < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :organizations, :slug, unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
