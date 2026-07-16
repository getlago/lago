# frozen_string_literal: true

class AddCancellationReasonToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_enum :subscription_cancellation_reasons, %w[payment_failed timeout]
    add_column :subscriptions, :cancellation_reason, :subscription_cancellation_reasons
  end
end
