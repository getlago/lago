# frozen_string_literal: true

class UpdateExportsCustomersToVersion6 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 6, revert_to_version: 5
  end
end
