# frozen_string_literal: true

class ValidateBillableMetricFiltersOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :billable_metric_filters, :organizations
  end
end
