# frozen_string_literal: true

class CreateFlatFilters < ActiveRecord::Migration[8.0]
  def change
    create_view :flat_filters
  end
end
