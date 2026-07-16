# frozen_string_literal: true

class AddDeletedAtToTaxes < ActiveRecord::Migration[8.0]
  def change
    add_column :taxes, :deleted_at, :datetime
  end
end
