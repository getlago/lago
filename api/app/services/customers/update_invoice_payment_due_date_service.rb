# frozen_string_literal: true

module Customers
  class UpdateInvoicePaymentDueDateService < BaseService
    Result = BaseResult[:customer]

    def initialize(customer:, net_payment_term:)
      @customer = customer
      @net_payment_term = net_payment_term
      super
    end

    def call
      ActiveRecord::Base.transaction do
        if net_payment_term != customer.net_payment_term

          # note: we should compare with the applicable_net_payment_term
          should_update_draft_invoices = net_payment_term != customer.applicable_net_payment_term

          # But we always store the value!
          customer.net_payment_term = net_payment_term

          # NOTE: Update payment_due_date if applicable_net_payment_term changed
          if should_update_draft_invoices
            customer.invoices.draft.find_each do |invoice|
              invoice.update!(net_payment_term: customer.applicable_net_payment_term, payment_due_date: invoice_payment_due_date(invoice))
            end
          end
        end
      end
      result.customer = customer
      result
    end

    private

    attr_reader :customer, :net_payment_term

    def invoice_payment_due_date(invoice)
      invoice.issuing_date + customer.applicable_net_payment_term.days
    end
  end
end
