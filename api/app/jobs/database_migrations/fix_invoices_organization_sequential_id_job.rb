# frozen_string_literal: true

module DatabaseMigrations
  class FixInvoicesOrganizationSequentialIdJob < ApplicationJob
    queue_as :default

    def perform
      Organization.per_organization.find_each do |organization|
        last_organization_sequential_id = organization.invoices.maximum(:organization_sequential_id) || 0
        invoices_count = organization.invoices.non_self_billed.with_generated_number.count

        next if last_organization_sequential_id == invoices_count

        last_invoice = organization.invoices.non_self_billed.with_generated_number.order(created_at: :desc).limit(1)
        last_invoice.update_all(organization_sequential_id: invoices_count) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
