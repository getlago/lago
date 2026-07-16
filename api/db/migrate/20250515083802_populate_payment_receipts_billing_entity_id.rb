# frozen_string_literal: true

class PopulatePaymentReceiptsBillingEntityId < ActiveRecord::Migration[8.0]
  def change
    PaymentReceipt.where(billing_entity_id: nil).update_all("billing_entity_id = organization_id") # rubocop:disable Rails/SkipsModelValidations
  end
end
