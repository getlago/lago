# frozen_string_literal: true

class UpdateExportsCustomersToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 3, revert_to_version: 2
  end
end
