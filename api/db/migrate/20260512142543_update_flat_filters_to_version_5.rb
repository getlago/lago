# frozen_string_literal: true

class UpdateFlatFiltersToVersion5 < ActiveRecord::Migration[8.0]
  def change
    update_view :flat_filters, version: 5, revert_to_version: 4
  end
end
