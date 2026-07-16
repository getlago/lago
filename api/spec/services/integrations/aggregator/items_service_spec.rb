# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::ItemsService do
  subject(:items_service) { described_class.new(integration:) }

  let(:integration) { create(:netsuite_integration) }

  describe ".call" do
    let(:aggregator_response) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/items_response.json")
      JSON.parse(File.read(path))
    end

    before do
      stub_request(:get, "https://api.nango.dev/v1/netsuite/items?limit=450")
        .to_return(
          status: 200,
          body: aggregator_response.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      IntegrationItem.destroy_all
    end

    it "uses id as external_id for netsuite" do
      result = items_service.call

      expect(result.items.pluck("external_id")).to eq(%w[755 745 753 484 828])
      expect(IntegrationItem.count).to eq(5)
    end

    context "when cursor is present" do
      let(:aggregator_response) do
        super().merge("next_cursor" => "abc123")
      end

      before do
        second_page_response = {
          "records" => [
            {
              "id" => "799",
              "item_code" => "test-lead-conduit-page-2",
              "name" => "Test-LeadConduit: Page 2",
              "account_code" => "7691"
            }
          ]
        }
        stub_request(:get, "https://api.nango.dev/v1/netsuite/items?limit=450&cursor=abc123")
          .to_return(
            status: 200,
            body: second_page_response.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes subsequent requests until cursor is nil" do
        result = items_service.call

        expect(result.items.pluck("external_id")).to eq(%w[755 745 753 484 828 799])
        expect(IntegrationItem.count).to eq(6)
      end
    end

    context "with a xero integration" do
      let(:integration) { create(:xero_integration) }

      before do
        stub_request(:get, "https://api.nango.dev/v1/xero/items?limit=450")
          .to_return(
            status: 200,
            body: aggregator_response.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "uses item_code as external_id for xero" do
        result = items_service.call

        expect(result.items.pluck("external_id")).to eq(
          ["test-lead-conduit", "test-trusted-form", "test-anura", "test-platform", "test-lead-conduit-add-on"]
        )
        expect(IntegrationItem.count).to eq(5)
      end

      context "with duplicate item_code in response" do
        let(:aggregator_response) do
          {
            "records" => [
              {
                "id" => "old-id",
                "item_code" => "VM6",
                "name" => "Old Item",
                "account_code" => "1234",
                "_nango_metadata" => {
                  "last_modified_at" => "2024-01-01T00:00:00+00:00"
                }
              },
              {
                "id" => "new-id",
                "item_code" => "VM6",
                "name" => "New Item",
                "account_code" => "1234",
                "_nango_metadata" => {
                  "last_modified_at" => "2024-06-01T00:00:00+00:00"
                }
              }
            ],
            "next_cursor" => nil
          }
        end

        it "keeps only the most recent item based on last_modified_at" do
          result = items_service.call

          expect(result.items.count).to eq(1)
          expect(result.items.first.external_id).to eq("VM6")
          expect(result.items.first.external_name).to eq("New Item")
        end

        context "when metadata is not present" do
          let(:aggregator_response) do
            {
              "records" => [
                {
                  "id" => "old-id",
                  "item_code" => "VM6",
                  "name" => "Old Item",
                  "account_code" => "1234"
                },
                {
                  "id" => "new-id",
                  "item_code" => "VM6",
                  "name" => "New Item",
                  "account_code" => "1234",
                  "_nango_metadata" => {
                    "last_modified_at" => "2024-06-01T00:00:00+00:00"
                  }
                }
              ],
              "next_cursor" => nil
            }
          end

          it "keeps the item with metadata" do
            result = items_service.call

            expect(result.items.count).to eq(1)
            expect(result.items.first.external_id).to eq("VM6")
            expect(result.items.first.external_name).to eq("New Item")
          end
        end
      end
    end
  end

  describe "#action_path" do
    subject(:action_path_call) { items_service.action_path }

    let(:action_path) { "v1/netsuite/items" }

    it "returns the path" do
      expect(subject).to eq(action_path)
    end
  end
end
