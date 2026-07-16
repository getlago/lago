# frozen_string_literal: true

class UpdateFlatFiltersToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_view :flat_filters, version: 3, revert_to_version: 2
  end
end
