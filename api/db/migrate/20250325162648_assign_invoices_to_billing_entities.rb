# frozen_string_literal: true

class AssignInvoicesToBillingEntities < ActiveRecord::Migration[7.2]
  def change
    Invoice.find_in_batches(batch_size: 1000) do |batch|
      Invoice.where(id: batch.pluck(:id))
        .update_all("billing_entity_id = organization_id") # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
