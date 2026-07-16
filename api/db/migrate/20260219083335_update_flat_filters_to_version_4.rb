# frozen_string_literal: true

class UpdateFlatFiltersToVersion4 < ActiveRecord::Migration[8.0]
  def change
    update_view :flat_filters, version: 4, revert_to_version: 3
  end
end
