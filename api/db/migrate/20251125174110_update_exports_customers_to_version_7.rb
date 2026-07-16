# frozen_string_literal: true

class UpdateExportsCustomersToVersion7 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 7, revert_to_version: 6
  end
end
