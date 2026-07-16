# frozen_string_literal: true

class MigrateAppliedTaxesToBillingEntities < ActiveRecord::Migration[7.2]
  def up
    applicable_taxes = Tax.unscoped.where(applied_to_organization: true).pluck(:id, :organization_id)

    timestamp = Time.current
    rows = applicable_taxes.map do |tax_id, organization_id|
      {
        billing_entity_id: organization_id,
        tax_id: tax_id,
        created_at: timestamp,
        updated_at: timestamp,
        deleted_at: nil
      }
    end

    # rubocop:disable Rails/SkipsModelValidations
    BillingEntity::AppliedTax.insert_all(
      rows,
      unique_by: :index_billing_entities_taxes_on_billing_entity_id_and_tax_id
    )
    # rubocop:enable Rails/SkipsModelValidations
  end
end
