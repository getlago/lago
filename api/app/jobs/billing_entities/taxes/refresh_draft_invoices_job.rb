# frozen_string_literal: true

module BillingEntities
  module Taxes
    class RefreshDraftInvoicesJob < ApplicationJob
      queue_as :default

      def perform(billing_entity_id)
        billing_entity = BillingEntity.find_by(id: billing_entity_id)
        return unless billing_entity

        billing_entity.invoices.draft
          .in_batches do |batch|
            batch.update_all(ready_to_be_refreshed: true) # rubocop:disable Rails/SkipsModelValidations
          end
      end
    end
  end
end
