# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::TerminateRelationsJob do
  let(:customer) { create(:customer, :deleted) }

  it "calls the service" do
    allow(Customers::TerminateRelationsService)
      .to receive(:call)
      .with(customer:)
      .and_return(BaseService::Result.new)

    described_class.perform_now(customer_id: customer.id)

    expect(Customers::TerminateRelationsService)
      .to have_received(:call)
  end
end
