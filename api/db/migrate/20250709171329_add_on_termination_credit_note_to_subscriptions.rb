# frozen_string_literal: true

class AddOnTerminationCreditNoteToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_enum :subscription_on_termination_credit_note, %w[credit skip]
    add_column :subscriptions, :on_termination_credit_note, :enum, enum_type: "subscription_on_termination_credit_note", default: nil
  end
end
