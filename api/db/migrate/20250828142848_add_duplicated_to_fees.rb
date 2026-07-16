# frozen_string_literal: true

class AddDuplicatedToFees < ActiveRecord::Migration[8.0]
  def change
    add_column :fees, :duplicated_in_advance, :boolean, default: false
  end
end
