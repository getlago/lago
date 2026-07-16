# frozen_string_literal: true

class AddProviderSessionIdToPaymentIntents < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_intents, :provider_session_id, :string
  end
end
