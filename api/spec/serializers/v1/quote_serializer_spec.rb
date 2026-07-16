# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::QuoteSerializer do
  subject(:serializer) { described_class.new(quote, root_name: "quote", includes:) }

  let(:quote) { create(:quote) }
  let(:owner) { create(:membership, organization: quote.organization).user }
  let!(:quote_version) { create(:quote_version, quote:, organization: quote.organization) }
  let(:includes) { [] }
  let(:result) { JSON.parse(serializer.to_json) }

  before { create(:quote_owner, quote:, organization: quote.organization, user: owner) }

  it "serializes the object with its current version" do
    expect(result["quote"]).to include(
      "lago_id" => quote.id,
      "number" => quote.number,
      "order_type" => quote.order_type,
      "lago_customer_id" => quote.customer_id,
      "lago_subscription_id" => quote.subscription_id,
      "lago_organization_id" => quote.organization_id
    )

    expect(result["quote"]["current_version"]).to include("lago_id" => quote_version.id)
  end

  it "does not expose owners by default" do
    expect(result["quote"]).not_to have_key("owners")
  end

  context "when owners are included" do
    let(:includes) { %i[owners] }

    it "exposes the owners" do
      expect(result["quote"]["owners"]).to eq([{"lago_id" => owner.id, "email" => owner.email}])
    end
  end
end
