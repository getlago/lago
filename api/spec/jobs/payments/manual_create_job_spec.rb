# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::ManualCreateJob do
  let(:organization) { invoice.customer.organization }
  let(:invoice) { create(:invoice) }
  let(:params) { {invoice_id: invoice.id, amount_cents: invoice.total_amount_cents, reference: "ref1"} }

  it "calls the create service" do
    allow(Payments::ManualCreateService)
      .to receive(:call!).with(organization:, params:).and_return(BaseService::Result.new)

    described_class.perform_now(organization:, params:)

    expect(Payments::ManualCreateService).to have_received(:call!)
  end
end
