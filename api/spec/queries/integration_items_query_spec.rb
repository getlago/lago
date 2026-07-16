# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationItemsQuery do
  subject(:result) do
    described_class.call(organization:, search_term:, pagination:, filters:)
  end

  let(:returned_ids) { result.integration_items.pluck(:id) }
  let(:pagination) { nil }
  let(:search_term) { nil }
  let(:filters) { {} }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:integration) { create(:netsuite_integration, organization:) }
  let(:integration_second) { create(:netsuite_integration, organization:) }
  let(:integration_third) { create(:netsuite_integration) }

  let(:integration_item_first) { create(:integration_item, item_type: "tax", integration:) }
  let(:integration_item_second) { create(:integration_item, integration: integration_second) }
  let(:integration_item_third) { create(:integration_item, integration: integration_third) }
  let(:integration_item_fourth) { create(:integration_item, external_name: "Findme", integration:) }

  before do
    integration_item_first
    integration_item_second
    integration_item_third
    integration_item_fourth
  end

  it "returns all integration items of an organization" do
    expect(result).to be_success
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(integration_item_first.id)
    expect(returned_ids).to include(integration_item_second.id)
    expect(returned_ids).not_to include(integration_item_third.id)
    expect(returned_ids).to include(integration_item_fourth.id)
  end

  context "when integration items have the same values for the ordering criteria" do
    let(:integration_item_second) do
      create(
        :integration_item,
        id: "00000000-0000-0000-0000-000000000000",
        integration: integration_second,
        external_id: integration_item_first.external_id,
        created_at: integration_item_first.created_at
      )
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(3)
      expect(returned_ids).to include(integration_item_first.id)
      expect(returned_ids).to include(integration_item_second.id)
      expect(returned_ids.index(integration_item_first.id)).to be > returned_ids.index(integration_item_second.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.integration_items.count).to eq(1)
      expect(result.integration_items.current_page).to eq(2)
      expect(result.integration_items.prev_page).to eq(1)
      expect(result.integration_items.next_page).to be_nil
      expect(result.integration_items.total_pages).to eq(2)
      expect(result.integration_items.total_count).to eq(3)
    end
  end

  context "when filtering by integration_id" do
    let(:filters) { {integration_id: integration.id} }

    it "returns all integration items of an integration" do
      expect(returned_ids.count).to eq(2)
      expect(returned_ids).to include(integration_item_first.id)
      expect(returned_ids).not_to include(integration_item_second.id)
      expect(returned_ids).not_to include(integration_item_third.id)
      expect(returned_ids).to include(integration_item_fourth.id)
    end
  end

  context "when filtering by item type" do
    let(:filters) { {item_type: "tax"} }

    it "returns one integration item" do
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).to include(integration_item_first.id)
      expect(returned_ids).not_to include(integration_item_second.id)
      expect(returned_ids).not_to include(integration_item_third.id)
      expect(returned_ids).not_to include(integration_item_fourth.id)
    end
  end

  context "when searching by name" do
    let(:search_term) { "Findme" }

    it "returns one integration item" do
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).not_to include(integration_item_first.id)
      expect(returned_ids).not_to include(integration_item_second.id)
      expect(returned_ids).not_to include(integration_item_third.id)
      expect(returned_ids).to include(integration_item_fourth.id)
    end
  end
end
