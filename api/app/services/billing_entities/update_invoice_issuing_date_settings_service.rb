# frozen_string_literal: true

module BillingEntities
  class UpdateInvoiceIssuingDateSettingsService < BaseService
    Result = BaseResult[:billing_entity]

    def initialize(billing_entity:, params:)
      @billing_entity = billing_entity
      @params = params
      @previous_issuing_date_settings = {
        invoice_grace_period: billing_entity.invoice_grace_period,
        subscription_invoice_issuing_date_anchor: billing_entity.subscription_invoice_issuing_date_anchor,
        subscription_invoice_issuing_date_adjustment: billing_entity.subscription_invoice_issuing_date_adjustment
      }
      super
    end

    def call
      set_issuing_date_settings

      if billing_entity.changed? && billing_entity.save!
        Invoices::UpdateAllInvoiceIssuingDateFromBillingEntityJob.perform_later(billing_entity, previous_issuing_date_settings)
      end

      result.billing_entity = billing_entity
      result
    end

    private

    attr_reader :billing_entity, :params, :previous_issuing_date_settings

    def set_issuing_date_settings
      if params.key?(:subscription_invoice_issuing_date_anchor)
        billing_entity.subscription_invoice_issuing_date_anchor = params[:subscription_invoice_issuing_date_anchor]
      end

      if params.key?(:subscription_invoice_issuing_date_adjustment)
        billing_entity.subscription_invoice_issuing_date_adjustment = params[:subscription_invoice_issuing_date_adjustment]
      end

      if License.premium? && params.key?(:invoice_grace_period)
        billing_entity.invoice_grace_period = params[:invoice_grace_period]
      end
    end
  end
end
