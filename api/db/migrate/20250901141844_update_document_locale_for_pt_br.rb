# frozen_string_literal: true

class UpdateDocumentLocaleForPtBr < ActiveRecord::Migration[8.0]
  class BillingEntity < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  class Customer < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  def up
    Organization.where(document_locale: "pt_BR").update(document_locale: "pt-BR")
    BillingEntity.where(document_locale: "pt_BR").update(document_locale: "pt-BR")
    Customer.where(document_locale: "pt_BR").update(document_locale: "pt-BR")
  end

  def down
    Organization.where(document_locale: "pt-BR").update(document_locale: "pt_BR")
    BillingEntity.where(document_locale: "pt-BR").update(document_locale: "pt_BR")
    Customer.where(document_locale: "pt-BR").update(document_locale: "pt_BR")
  end
end
