# frozen_string_literal: true

class CreateExportsItemMetadata < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_item_metadata
  end
end
