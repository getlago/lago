# frozen_string_literal: true

class AddPhoneToBillingEntities < ActiveRecord::Migration[8.0]
  def change
    add_column :billing_entities, :phone, :string
  end
end
