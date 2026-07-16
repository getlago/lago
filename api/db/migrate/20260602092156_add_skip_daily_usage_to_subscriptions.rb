# frozen_string_literal: true

class AddSkipDailyUsageToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :skip_daily_usage, :boolean, default: false, null: false
  end
end
