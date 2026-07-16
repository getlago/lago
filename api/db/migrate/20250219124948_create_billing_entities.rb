# frozen_string_literal: true

class CreateBillingEntities < ActiveRecord::Migration[7.1]
  def change
    create_enum :entity_document_numbering, %w[per_customer per_billing_entity]

    create_table :billing_entities, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true

      # address
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :country
      t.string :zipcode
      t.string :state
      t.string :timezone, default: "UTC", null: false

      # currency and locale
      t.string :default_currency, default: "USD", null: false
      t.string :document_locale, default: "en", null: false

      # invoice settings
      t.string :document_number_prefix
      t.enum :document_numbering, enum_type: "entity_document_numbering", null: false, default: "per_customer"
      t.boolean :finalize_zero_amount_invoice, default: true, null: false
      t.text :invoice_footer
      t.integer :invoice_grace_period, default: 0, null: false
      t.integer :net_payment_term, default: 0, null: false

      # entity settings
      t.string :email
      t.string :email_settings, array: true, default: [], null: false
      t.boolean :eu_tax_management, default: false
      t.string :legal_name
      t.string :legal_number
      t.string :logo
      t.string :name, null: false
      t.string :code, null: false
      t.string :tax_identification_number
      t.float :vat_rate, default: 0.0, null: false

      t.boolean :is_default, default: false, null: false
      t.index [:organization_id],
        unique: true,
        where: "is_default = TRUE AND archived_at IS NULL AND deleted_at IS NULL",
        name: "unique_default_billing_entity_per_organization"

      t.datetime :archived_at
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
