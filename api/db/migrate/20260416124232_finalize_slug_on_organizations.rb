# frozen_string_literal: true

class FinalizeSlugOnOrganizations < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      change_column_null :organizations, :slug, false
      change_column_default :organizations, :slug, from: -> { "'org-' || substr(md5(random()::text), 1, 8)" }, to: nil
    end
  end

  def down
    change_column_default :organizations, :slug, from: nil, to: -> { "'org-' || substr(md5(random()::text), 1, 8)" }
    change_column_null :organizations, :slug, true
  end
end
