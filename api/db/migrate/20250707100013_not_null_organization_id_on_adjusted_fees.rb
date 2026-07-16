# frozen_string_literal: true

class NotNullOrganizationIdOnAdjustedFees < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :adjusted_fees, name: "adjusted_fees_organization_id_not_null"
    change_column_null :adjusted_fees, :organization_id, false
    remove_check_constraint :adjusted_fees, name: "adjusted_fees_organization_id_not_null"
  end

  def down
    add_check_constraint :adjusted_fees, "organization_id IS NOT NULL", name: "adjusted_fees_organization_id_not_null", validate: false
    change_column_null :adjusted_fees, :organization_id, true
  end
end
