# frozen_string_literal: true

# Performance benchmark for the credit notes index action.
#
# Runs both the old (N+1) and new (eager-loaded) query strategies against the
# same dataset in the same spec run — no git operations or stashing needed.
#
# Usage:
#   - Uncomment lines 54, 68 and 120 to see the output
#   - Change CREDIT_NOTE_COUNT and ITEMS_PER_NOTE to the desired number of records
#   - Run bundle exec rspec spec/performance/credit_notes_index_spec.rb --format documentation

require "rails_helper"
require "benchmark"

CREDIT_NOTE_COUNT = 2
ITEMS_PER_NOTE = 6 # 3 subscription fees + 3 charge fees

# rubocop:disable Lint/UselessAssignment
RSpec.describe "Credit notes index performance", type: :request do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, :with_stripe_payment_provider, organization:) }
  let(:membership) { create(:membership, organization:) }

  before do
    subscription = create(:subscription, customer:, organization:)

    CREDIT_NOTE_COUNT.times do
      inv = create(:invoice, customer:, organization:)

      fees = 3.times.flat_map do
        [
          create(:fee, invoice: inv, subscription:, organization:),
          create(:charge_fee, invoice: inv, subscription:, organization:)
        ]
      end

      cn = create(:credit_note, customer:, invoice: inv, organization:)
      fees.each { |fee| create(:credit_note_item, credit_note: cn, fee:, organization:) }
      create(:credit_note_applied_tax, credit_note: cn, organization:)
    end
  end

  def measure(label)
    query_count = 0
    counter = ->(*) { query_count += 1 }

    elapsed_ms = Benchmark.realtime do
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        yield
      end
    end * 1000

    # puts "\n  %-60s queries: %3d   time: %6.1fms" % [label, query_count, elapsed_ms]
    query_count
  end

  def serialize(credit_notes)
    CollectionSerializer.new(
      credit_notes,
      V1::CreditNoteSerializer,
      collection_name: "credit_notes",
      includes: %i[items applied_taxes error_details customer]
    ).serialize
  end

  it "compares old vs new query strategy — REST serialization path" do
    # puts "\n\n  === Credit notes index: old vs new (#{CREDIT_NOTE_COUNT} notes, #{ITEMS_PER_NOTE} fee items each) ===\n"

    old_count = measure("OLD — customer join, items only, no fee tree") do
      credit_notes = CreditNote
        .joins(:customer)
        .where("customers.organization_id = ?", organization.id)
        .finalized
        .includes(
          :customer,
          :items,
          :applied_taxes,
          :file_attachment,
          :xml_file_attachment,
          :error_details,
          :metadata,
          invoice: :billing_entity
        )
        .page(1).per(CREDIT_NOTE_COUNT)

      serialize(credit_notes)
    end

    new_count = measure("NEW — full fee tree preloaded, items.sort_by in memory") do
      credit_notes = CreditNote
        .where(organization:)
        .finalized
        .includes(
          :applied_taxes,
          :file_attachment,
          :xml_file_attachment,
          :error_details,
          :metadata,
          invoice: :billing_entity,
          items: {
            fee: [
              :charge_filter,
              :charge,
              :billable_metric,
              :invoice,
              :pricing_unit_usage,
              :true_up_fee,
              {subscription: :plan},
              :customer
            ]
          },
          customer: [:billing_entity, :metadata, :stripe_customer, :gocardless_customer, :cashfree_customer, :adyen_customer, :moneyhash_customer]
        ).page(1).per(CREDIT_NOTE_COUNT)

      serialize(credit_notes)
    end

    reduction = ((old_count - new_count).to_f / old_count * 100).round
    # puts "\n  Reduction: #{old_count} → #{new_count} queries (#{reduction}% fewer)\n\n"

    expect(new_count).to be < old_count
  end
end
# rubocop:enable Lint/UselessAssignment
