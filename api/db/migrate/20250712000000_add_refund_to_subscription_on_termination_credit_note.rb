# frozen_string_literal: true

class AddRefundToSubscriptionOnTerminationCreditNote < ActiveRecord::Migration[7.1]
  def up
    add_enum_value :subscription_on_termination_credit_note, "refund", if_not_exists: true
  end

  def down
    # No rollback needed as removing enum values is not supported
  end
end
