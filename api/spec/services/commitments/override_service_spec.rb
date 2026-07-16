# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitments::OverrideService do
  subject(:override_service) { described_class.new(commitment:, params:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  describe "#call" do
    let(:plan) { create(:plan, organization:) }
    let(:params) do
      {
        plan_id: plan.id,
        invoice_display_name: "invoice display name",
        amount_cents: 1000,
        tax_codes: [tax.code]
      }
    end

    let(:tax) { create(:tax, organization:) }
    let(:commitment) { build(:commitment, plan:) }

    context "when lago freemium" do
      it "returns without overriding the commitment" do
        expect { override_service.call }.not_to change(Commitment, :count)
      end
    end

    context "when lago premium", :premium do
      it "creates a commitment based on the given commitment" do
        expect { override_service.call }.to change(Commitment, :count).by(1)

        commitment = Commitment.order(:created_at).last

        expect(commitment.taxes).to contain_exactly(tax)
        expect(commitment).to have_attributes(
          plan_id: plan.id,
          invoice_display_name: "invoice display name",
          amount_cents: 1000
        )
        expect(commitment.taxes).to contain_exactly(tax)
      end
    end
  end
end
