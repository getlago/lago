# frozen_string_literal: true

class UpdateExportsCustomersToVersion5 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 5, revert_to_version: 4
  end
end
