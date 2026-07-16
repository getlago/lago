# frozen_string_literal: true

class AddOffsetValueToSubscriptionOnTerminationCreditNoteEnum < ActiveRecord::Migration[8.0]
  def up
    add_enum_value :subscription_on_termination_credit_note, "offset", if_not_exists: true
  end

  def down
  end
end
