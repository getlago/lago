# frozen_string_literal: true

class AddOrganizationIdToBillableMetricFilters < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :billable_metric_filters, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
