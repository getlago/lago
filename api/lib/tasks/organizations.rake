# frozen_string_literal: true

namespace :organizations do
  desc "Think couple times before running this!!! It will delete all the data related to invoices, credit notes and events"
  task :delete_invoices_data, [:org_id] => :environment do |_task, args|
    organization = Organization.find(args[:org_id])
    organization.invoices.find_each do |invoice|
      invoice.credit_notes.find_each do |credit_note|
        Credit.where(credit_note_id: credit_note.id).destroy_all
        WalletTransaction.where(credit_note_id: credit_note.id).destroy_all
        credit_note.destroy
      end
      invoice.fees.find_each do |fee|
        fee.adjusted_fee&.destroy
        fee.destroy
      end
      invoice.invoice_subscriptions.destroy_all
      AdjustedFee.where(invoice_id: invoice.id).destroy_all
      Credit.where(invoice_id: invoice.id).destroy_all
      WalletTransaction.where(invoice_id: invoice.id).destroy_all
      invoice.destroy
    end

    organization.events.destroy_all
  end
end
