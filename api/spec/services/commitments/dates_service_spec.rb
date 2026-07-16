# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitments::DatesService do
  let(:commitment) { create(:commitment) }
  let(:invoice_subscription) { create(:invoice_subscription, subscription:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:, pay_in_advance:) }

  describe ".new_instance" do
    subject(:new_instance_call) { described_class.new_instance(commitment:, invoice_subscription:) }

    context "when plan is paid in arrears" do
      let(:pay_in_advance) { false }

      it "returns a dates service object" do
        expect(new_instance_call).to be_a Commitments::Minimum::InArrears::DatesService
      end
    end

    context "when plan is paid in advance" do
      let(:pay_in_advance) { true }

      it "returns a dates service object" do
        expect(new_instance_call).to be_a Commitments::Minimum::InAdvance::DatesService
      end
    end
  end

  describe "#call" do
    subject(:service) { described_class.new_instance(commitment:, invoice_subscription:) }

    let(:pay_in_advance) { [false, true].sample }
    let(:terminated_service) { instance_double("Subscriptions::TerminatedDatesService") }

    before do
      allow(Subscriptions::TerminatedDatesService).to receive(:new).and_return(terminated_service)
      allow(terminated_service).to receive(:call).and_return(nil)

      service.call
    end

    context "when subscription is terminated" do
      let(:subscription) { create(:subscription, :terminated, customer:, plan:) }

      it "calls terminated dates service" do
        expect(Subscriptions::TerminatedDatesService).to have_received(:new)
      end
    end

    context "when subscription is not terminated" do
      it "does not call terminated dates service" do
        expect(Subscriptions::TerminatedDatesService).not_to have_received(:new)
      end
    end
  end
end
