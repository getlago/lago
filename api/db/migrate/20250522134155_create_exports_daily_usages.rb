# frozen_string_literal: true

class CreateExportsDailyUsages < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_daily_usages
  end
end
