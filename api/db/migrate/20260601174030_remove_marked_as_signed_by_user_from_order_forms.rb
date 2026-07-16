# frozen_string_literal: true

class RemoveMarkedAsSignedByUserFromOrderForms < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_reference :order_forms, :marked_as_signed_by_user,
        foreign_key: {to_table: :users},
        type: :uuid
    end
  end
end
