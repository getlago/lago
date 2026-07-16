# frozen_string_literal: true

class UpdateExportsChargesToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_charges, version: 3, revert_to_version: 2
  end
end
