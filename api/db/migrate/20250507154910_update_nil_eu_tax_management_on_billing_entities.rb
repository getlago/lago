# frozen_string_literal: true

class UpdateNilEuTaxManagementOnBillingEntities < ActiveRecord::Migration[8.0]
  class BillingEntity < ApplicationRecord
    attribute :subscription_invoice_issuing_date_anchor, :string, default: "next_period_start"
    attribute :subscription_invoice_issuing_date_adjustment, :string, default: "keep_anchor"
  end

  def change
    # rubocop:disable Rails/SkipsModelValidations
    BillingEntity.where(eu_tax_management: nil).update_all(eu_tax_management: false)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
