# frozen_string_literal: true

module Invoices
  class UpdateAllInvoiceIssuingDateFromBillingEntityService < BaseService
    Result = BaseResult

    def initialize(billing_entity:, previous_issuing_date_settings:)
      @billing_entity = billing_entity
      @previous_issuing_date_settings = previous_issuing_date_settings

      super
    end

    def call
      billing_entity.invoices.draft.find_each do |invoice|
        Invoices::UpdateIssuingDateFromBillingEntityJob.perform_later(invoice, previous_issuing_date_settings)
      end

      result
    end

    private

    attr_reader :billing_entity, :previous_issuing_date_settings
  end
end
