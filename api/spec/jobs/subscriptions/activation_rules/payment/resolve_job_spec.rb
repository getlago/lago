# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::Payment::ResolveJob do
  subject(:job) { described_class.perform_now(subscription, invoice, payment_status) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, :incomplete, organization:, customer:) }
  let(:invoice) { create(:invoice, organization:, customer:, status: :open, invoice_type: :subscription) }
  let(:payment_status) { "failed" }

  before do
    allow(Subscriptions::ActivationRules::Payment::ResolveService).to receive(:call!)
  end

  it "calls ResolveService with the correct arguments" do
    job

    expect(Subscriptions::ActivationRules::Payment::ResolveService).to have_received(:call!)
      .with(subscription:, invoice:, payment_status:)
  end
end
