# frozen_string_literal: true

class AddSlugToOrganizations < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      add_column :organizations, :slug, :string
      change_column_default :organizations, :slug, from: nil, to: -> { "'org-' || substr(md5(random()::text), 1, 8)" }
    end
  end

  def down
    remove_column :organizations, :slug # rubocop:disable Lago/NoDropColumnOrTable
  end
end
