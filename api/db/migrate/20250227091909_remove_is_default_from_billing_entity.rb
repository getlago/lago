# frozen_string_literal: true

class RemoveIsDefaultFromBillingEntity < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :billing_entities, :is_default, :boolean, default: false, null: false
    end
  end
end
