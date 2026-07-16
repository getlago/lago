# frozen_string_literal: true

class EnsureOrganizationLastInvoiceGotOrganizationSequentialId < ActiveRecord::Migration[7.2]
  def change
    DatabaseMigrations::FixInvoicesOrganizationSequentialIdJob.perform_later
  end
end
