# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Invoices::CreatedService do
  subject(:webhook_service) { described_class.new(object: invoice) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  let(:charge) do
    create(:standard_charge, properties: {
      "amount" => "100",
      "presentation_group_keys" => [{"value" => "department", "options" => {"display_in_invoice" => true}}]
    })
  end

  before do
    create(:charge_fee, charge:, invoice:, presentation_breakdowns: [build(:presentation_breakdown)])
    create_list(:fee, 3, invoice:)
    create_list(:credit, 4, invoice:)
  end

  describe ".call" do
    it_behaves_like "creates webhook", "invoice.created", "invoice", {"fees" => Array, "credits" => Array}

    it "includes presentation_breakdowns in fees" do
      webhook_service.call

      webhook = Webhook.order(created_at: :desc).first
      fees = webhook.payload["invoice"]["fees"]

      expect(fees).to include(
        hash_including(
          "presentation_breakdowns" => [
            hash_including("presentation_by" => {"department" => "engineering"}, "units" => "60.0")
          ]
        ),
        hash_including("presentation_breakdowns" => [])
      )
    end
  end
end
