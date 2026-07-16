# frozen_string_literal: true

module BillingEntities
  class UpdateInvoicePaymentDueDateService < BaseService
    Result = BaseResult[:billing_entity]

    def initialize(billing_entity:, net_payment_term:)
      @billing_entity = billing_entity
      @net_payment_term = net_payment_term
      super
    end

    def call
      ActiveRecord::Base.transaction do
        # NOTE: Set payment_due_date if net_payment_term changed
        if billing_entity.net_payment_term != net_payment_term
          billing_entity.net_payment_term = net_payment_term

          # update only invoices, where the customer does not have a setting
          billing_entity.invoices.includes(:customer).draft.find_each do |invoice|
            # the customer has a setting of their own, no update needed.
            next unless invoice.customer.net_payment_term.nil?

            invoice.update!(net_payment_term:, payment_due_date: invoice_payment_due_date(invoice))
          end
        end

        result.billing_entity = billing_entity
        result
      end
    end

    private

    attr_reader :billing_entity, :net_payment_term

    def invoice_payment_due_date(invoice)
      invoice.issuing_date + net_payment_term.days
    end
  end
end
