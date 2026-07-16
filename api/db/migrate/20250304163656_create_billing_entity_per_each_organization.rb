# frozen_string_literal: true

class CreateBillingEntityPerEachOrganization < ActiveRecord::Migration[7.2]
  class Organization < ApplicationRecord
    has_many :billing_entities
    has_one :applied_dunning_campaign, -> { where(applied_to_organization: true) }, class_name: "DunningCampaign"

    DOCUMENT_NUMBERINGS = {
      per_customer: 0,
      per_organization: 1
    }.freeze
    attribute :document_numbering, :integer, default: 0
    enum :document_numbering, DOCUMENT_NUMBERINGS
  end

  class BillingEntity < ApplicationRecord
    belongs_to :organization

    DOCUMENT_NUMBERINGS = {
      per_customer: "per_customer",
      per_billing_entity: "per_billing_entity"
    }.freeze
    enum :document_numbering, DOCUMENT_NUMBERINGS
  end

  def up
    Organization.find_each do |organization|
      BillingEntity.create!(
        id: organization.id,
        organization_id: organization.id,
        name: organization.name,
        code: organization.name.parameterize(separator: "_"),
        address_line1: organization.address_line1,
        address_line2: organization.address_line2,
        city: organization.city,
        country: organization.country,
        zipcode: organization.zipcode,
        state: organization.state,
        timezone: organization.timezone,

        # currency and locale
        default_currency: organization.default_currency,
        document_locale: organization.document_locale,

        # invoice settings
        document_number_prefix: organization.document_number_prefix,
        document_numbering: organization.per_organization? ? "per_billing_entity" : "per_customer",
        finalize_zero_amount_invoice: organization.finalize_zero_amount_invoice,
        invoice_footer: organization.invoice_footer,
        invoice_grace_period: organization.invoice_grace_period,

        # entity settings
        email: organization.email,
        email_settings: organization.email_settings,
        eu_tax_management: organization.eu_tax_management,
        legal_name: organization.legal_name,
        legal_number: organization.legal_number,
        logo: organization.logo,
        tax_identification_number: organization.tax_identification_number,
        vat_rate: organization.vat_rate,
        applied_dunning_campaign_id: organization.applied_dunning_campaign&.id
      )
    end
  end

  def down
    BillingEntity.delete_all
  end
end
