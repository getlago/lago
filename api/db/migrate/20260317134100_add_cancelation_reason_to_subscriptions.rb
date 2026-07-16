# frozen_string_literal: true

class AddCancelationReasonToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :cancelation_reason, :subscription_cancelation_reasons
  end
end
