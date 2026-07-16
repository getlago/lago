# frozen_string_literal: true

module Invoices
  class UpdateAllInvoiceIssuingDateFromBillingEntityJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :invoices
      end
    end

    def perform(billing_entity, previous_issuing_date_settings)
      Invoices::UpdateAllInvoiceIssuingDateFromBillingEntityService.call!(billing_entity:, previous_issuing_date_settings:)
    end
  end
end
