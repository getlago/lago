# frozen_string_literal: true

class UpdateExportsCustomersToVersion2 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 2, revert_to_version: 1
  end
end
