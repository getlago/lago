# frozen_string_literal: true

class AddOrganizationIdFkToBillableMetricFilters < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :billable_metric_filters, :organizations, validate: false
  end
end
