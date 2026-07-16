# frozen_string_literal: true

class NotNullOrganizationIdOnBillableMetricFilters < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :billable_metric_filters, name: "billable_metric_filters_organization_id_null"
    change_column_null :billable_metric_filters, :organization_id, false
    remove_check_constraint :billable_metric_filters, name: "billable_metric_filters_organization_id_null"
  end

  def down
    add_check_constraint :billable_metric_filters, "organization_id IS NOT NULL", name: "billable_metric_filters_organization_id_null", validate: false
    change_column_null :billable_metric_filters, :organization_id, true
  end
end
