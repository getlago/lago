# frozen_string_literal: true

class UpdateExportsCustomersToVersion4 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_customers, version: 4, revert_to_version: 3
  end
end
