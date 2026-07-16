# frozen_string_literal: true

# Verifies that offset_amount_cents is batch-loaded in a single aggregated query
# instead of N+1 individual queries per invoice.
#
# The caller must define:
# - `preloadable_invoices`: an array of at least 2 invoices to attach credit notes to
# - `subject`: the action that triggers loading and serializing invoices
RSpec.shared_examples "preloads offset amounts" do
  before do
    preloadable_invoices.each do |invoice|
      create(:credit_note, status: :finalized, invoice:, offset_amount_cents: 100)
    end
  end

  it "uses a single aggregated query instead of N+1" do
    query_count = 0
    counter = ->(_name, _start, _finish, _id, payload) {
      query_count += 1 if /SELECT SUM.*offset_amount_cents.*FROM.*credit_notes/i.match?(payload[:sql])
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      subject
    end

    expect(query_count).to eq(1), "Expected single query to credit_notes table, but got #{query_count}"
  end
end
