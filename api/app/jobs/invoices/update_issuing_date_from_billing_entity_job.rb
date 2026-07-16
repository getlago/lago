# frozen_string_literal: true

module Invoices
  class UpdateIssuingDateFromBillingEntityJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_BILLING"])
        :billing
      else
        :invoices
      end
    end

    def perform(invoice, previous_issuing_date_settings)
      Invoices::UpdateIssuingDateFromBillingEntityService.call!(invoice:, previous_issuing_date_settings:)
    end
  end
end
