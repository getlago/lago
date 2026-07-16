# frozen_string_literal: true

class UpdateExportsCreditNotesToVersion4 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_credit_notes, version: 4, revert_to_version: 3
  end
end
