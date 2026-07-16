# frozen_string_literal: true

class UpdateFlatFiltersToVersion2 < ActiveRecord::Migration[8.0]
  def change
    update_view :flat_filters, version: 2, revert_to_version: 1
  end
end
