# frozen_string_literal: true

class MigrateInvoiceErrorToErrorDetail < ActiveRecord::Migration[7.1]
  class InvoiceError < ApplicationRecord; end

  class ErrorDetail < ApplicationRecord
    belongs_to :owner, polymorphic: true
  end

  def change
    InvoiceError.find_each do |ie|
      invoice = Invoice.find(ie.id)
      ErrorDetail.create(
        error_code: "invoice_generation_error",
        owner: invoice,
        organization_id: invoice.organization_id,
        created_at: ie.created_at,
        updated_at: ie.updated_at,
        details: {
          error: ie.error,
          backtrace: ie.backtrace,
          invoice: ie.invoice,
          subscriptions: ie.subscriptions
        }
      )
    end
  end
end
