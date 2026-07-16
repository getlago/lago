# frozen_string_literal: true

class AddFeatureFlagsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :feature_flags, :string, array: true, default: [], null: false
  end
end
