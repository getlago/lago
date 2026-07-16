# frozen_string_literal: true

class CreateSubscriptionCancelationReasons < ActiveRecord::Migration[8.0]
  def up
    create_enum :subscription_cancelation_reasons, %w[payment_failed timeout]
  end

  def down
    drop_enum :subscription_cancelation_reasons
  end
end
