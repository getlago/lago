# frozen_string_literal: true

class AddPreFilterEventsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :pre_filter_events, :boolean, default: false, null: false
  end
end
