# frozen_string_literal: true

class DropPropertiesFromEnrichedEvents < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      remove_column :enriched_events, :properties
    end
  end
end
