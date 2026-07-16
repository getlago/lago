# frozen_string_literal: true

class CreateBillingEntityInvoiceCustomSectionsRecords < ActiveRecord::Migration[8.0]
  class InvoiceCustomSectionSelection < ApplicationRecord
    belongs_to :organization, optional: true
  end

  class Organization < ApplicationRecord
    has_one :default_billing_entity, -> { active.order(created_at: :asc) }, class_name: "BillingEntity"
  end

  class BillingEntity < ApplicationRecord
    scope :active, -> { where(archived_at: nil).order(created_at: :asc) }
  end

  class BillingEntity::AppliedInvoiceCustomSection < ApplicationRecord
    self.table_name = "billing_entities_invoice_custom_sections"
  end

  def up
    BillingEntity::AppliedInvoiceCustomSection.insert_all( # rubocop:disable Rails/SkipsModelValidations
      InvoiceCustomSectionSelection
        .where.not(organization_id: nil)
        .includes(organization: :default_billing_entity)
        .map do |selection|
          {
            id: selection.id,
            organization_id: selection.organization_id,
            billing_entity_id: selection.organization.default_billing_entity.id,
            invoice_custom_section_id: selection.invoice_custom_section_id,
            created_at: selection.created_at,
            updated_at: selection.updated_at
          }
        end
    )
  end

  def down
    BillingEntity::AppliedInvoiceCustomSection.delete_all
  end
end
