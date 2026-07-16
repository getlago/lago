# frozen_string_literal: true

class AddDailyUsageIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :daily_usages,
        [:subscription_id, :usage_date],
        name: :index_daily_usages_on_subscription_id_and_usage_date,
        algorithm: :concurrently,
        if_not_exists: true
    end
  end
end
