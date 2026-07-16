# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentIntents::ExpireJob do
  let(:invoice) { create(:invoice) }

  before do
    allow(PaymentIntents::ExpireService)
      .to receive(:call!).with(invoice:).and_return(BaseService::Result.new)
  end

  it "calls the expire service" do
    described_class.perform_now(invoice)

    expect(PaymentIntents::ExpireService).to have_received(:call!).with(invoice:)
  end
end
