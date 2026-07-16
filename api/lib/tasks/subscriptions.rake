# frozen_string_literal: true

namespace :subscriptions do
  desc "Fill missing unique_id"
  task fill_unique_id: :environment do
    Subscription.includes(:customer).find_each do |subscription|
      subscription.update!(unique_id: subscription.customer.customer_id)
    end
  end

  # NOTE: Ability to create invoices in the future.
  # How to use it: bundle exec rake "subscriptions:generate_invoice[timestamp, external_id1, external_id2, ...]"
  # ie bundle exec rake "subscriptions:generate_invoice[1675267200, 7ee92df2-0d15-48df-a57b-593c529f50b3]"
  desc "Generate invoice for a specific timestamp"
  task :generate_invoice, [:timestamp] => :environment do |_task, args|
    abort "Missing timestamp and external subscription ids\n\n" unless args[:timestamp]
    abort "Missing external subscription ids\n\n" if args.extras.blank?

    subscriptions = Subscription.where(external_id: args.extras)

    abort "External subscription ids not found\n\n" if subscriptions.blank?
    abort "Subscriptions don't belong to the same customer\n\n" if subscriptions.pluck(:customer_id).uniq.count > 1

    result = Invoices::SubscriptionService.call(
      subscriptions:,
      timestamp: args[:timestamp].to_i,
      recurring: false
    )
    invoice = result.invoice

    invoice.update!(created_at: Time.zone.at(args[:timestamp].to_i))
    invoice.fees.update_all(created_at: invoice.created_at + 1.second) # rubocop:disable Rails/SkipsModelValidations

    # NOTE: Do not generate the PDF file if invoice is draft.
    Invoices::GeneratePdfService.call(invoice:) if invoice.finalized?
  end
end
