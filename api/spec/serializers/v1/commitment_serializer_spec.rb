# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::CommitmentSerializer do
  subject(:serializer) do
    described_class.new(commitment, root_name: "commitment", includes: %i[taxes])
  end

  let(:commitment) { create(:commitment) }
  let(:tax) { create(:tax, organization: commitment.plan.organization) }
  let(:commitment_applied_tax) { create(:commitment_applied_tax, commitment:, tax:) }

  let(:commitment_hash) do
    {
      "lago_id" => commitment.id,
      "plan_code" => commitment.plan.code,
      "invoice_display_name" => commitment.invoice_display_name,
      "commitment_type" => commitment.commitment_type,
      "amount_cents" => commitment.amount_cents,
      "interval" => commitment.plan.interval,
      "created_at" => commitment.created_at.iso8601,
      "updated_at" => commitment.updated_at.iso8601
    }
  end

  let(:commitment_tax_hash) do
    {
      "lago_id" => tax.id,
      "name" => tax.name,
      "code" => tax.code,
      "rate" => tax.rate,
      "description" => tax.description,
      "applied_to_organization" => tax.applied_to_organization,
      "commitments_count" => 0
    }
  end

  before { commitment_applied_tax }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["commitment"]).to include(commitment_hash)
  end

  it "serializes taxes" do
    result = JSON.parse(serializer.to_json)

    expect(result["commitment"]["taxes"].first).to include(commitment_tax_hash)
  end
end
