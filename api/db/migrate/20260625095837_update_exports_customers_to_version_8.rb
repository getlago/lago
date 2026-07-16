# frozen_string_literal: true

class UpdateExportsCustomersToVersion8 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 8, revert_to_version: 7
  end
end
