# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::QuoteVersionSerializer do
  subject(:serializer) { described_class.new(quote_version, root_name: "quote_version", includes:) }

  let(:quote_version) { create(:quote_version, :approved) }
  let(:includes) { [] }
  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the slim fields" do
    expect(result["quote_version"]).to include(
      "lago_id" => quote_version.id,
      "lago_quote_id" => quote_version.quote_id,
      "lago_organization_id" => quote_version.organization_id,
      "version" => quote_version.version,
      "status" => "approved",
      "currency" => quote_version.currency,
      "void_reason" => nil,
      "approved_at" => quote_version.approved_at.iso8601
    )
  end

  it "does not expose content or billing_items by default" do
    expect(result["quote_version"].keys).not_to include("content", "billing_items")
  end

  it "never exposes the share_token" do
    expect(result["quote_version"]).not_to have_key("share_token")
  end

  context "when content and billing_items are included" do
    let(:includes) { %i[content billing_items] }

    it "exposes content and billing_items but not the share_token" do
      expect(result["quote_version"]).to include(
        "content" => quote_version.content,
        "billing_items" => quote_version.billing_items
      )
      expect(result["quote_version"]).not_to have_key("share_token")
    end
  end
end
