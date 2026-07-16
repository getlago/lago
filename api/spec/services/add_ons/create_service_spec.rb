# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddOns::CreateService do
  subject(:create_service) { described_class.new(create_args) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:add_on_code) { "free-beer-for-us" }
  let(:tax) { create(:tax, organization:) }

  describe "create" do
    let(:create_args) do
      {
        name: "Super Add-on",
        invoice_display_name: "Super Add-on Invoice Name",
        code: add_on_code,
        description: "This is description",
        organization_id: organization.id,
        amount_cents: 100,
        amount_currency: "EUR",
        tax_codes: [tax.code]
      }
    end

    before do
      allow(SegmentTrackJob).to receive(:perform_later)
    end

    it "creates an add-on" do
      expect { create_service.call }
        .to change(AddOn, :count).by(1)

      add_on = AddOn.order(:created_at).last
      expect(add_on.taxes.pluck(:code)).to eq([tax.code])
    end

    it "calls SegmentTrackJob" do
      add_on = create_service.call.add_on

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "add_on_created",
        properties: {
          addon_code: add_on.code,
          addon_name: add_on.name,
          addon_invoice_display_name: add_on.invoice_display_name,
          organization_id: add_on.organization_id
        }
      )
    end

    context "with code already used by a deleted add_on" do
      it "creates an add_on with the same code" do
        create(:add_on, :deleted, organization:, code: add_on_code)

        expect { create_service.call }.to change(AddOn, :count).by(1)

        add_ons = organization.add_ons.with_discarded
        expect(add_ons.count).to eq(2)
        expect(add_ons.pluck(:code).uniq).to eq([add_on_code])
      end
    end

    context "with validation error" do
      before do
        create(
          :add_on,
          organization:,
          code: "free-beer-for-us"
        )
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:code]).to eq(["value_already_exist"])
      end
    end
  end
end
