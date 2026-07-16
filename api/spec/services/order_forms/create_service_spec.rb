# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderForms::CreateService do
  subject(:create_service) { described_class.new(quote_version:) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:quote) { create(:quote, organization:) }
  let(:quote_version) { create(:quote_version, :approved, quote:, organization:) }

  describe ".call" do
    let(:result) { create_service.call }

    context "when the quote version is approved", :premium do
      it "creates an order form" do
        expect { result }.to change(OrderForm, :count).by(1)
      end

      it "returns the order form with the expected attributes" do
        expect(result).to be_success
        expect(result.order_form).to have_attributes(
          organization_id: organization.id,
          customer_id: quote.customer_id,
          quote_version_id: quote_version.id,
          status: "generated",
          expires_at: nil
        )
      end
    end

    context "when an expires_at in the future is provided", :premium do
      subject(:create_service) { described_class.new(quote_version:, expires_at:) }

      let(:expires_at) { 1.month.from_now }

      it "sets expires_at on the order form" do
        expect(result).to be_success
        expect(result.order_form.expires_at).to be_within(1.second).of(expires_at)
      end
    end

    context "when an expires_at in the past is provided", :premium do
      subject(:create_service) { described_class.new(quote_version:, expires_at:) }

      let(:expires_at) { 1.day.ago }

      it "does not create an order form" do
        expect { result }.not_to change(OrderForm, :count)
      end

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq(expires_at: ["invalid_date"])
      end
    end

    context "when the quote version is not approved", :premium do
      let(:quote_version) { create(:quote_version, quote:, organization:) }

      it "does not create an order form" do
        expect { result }.not_to change(OrderForm, :count)
      end

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({quote_version: ["not_approved"]})
      end
    end

    context "when license is not premium" do
      it "does not create an order form" do
        expect { result }.not_to change(OrderForm, :count)
      end

      it "returns a forbidden failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when an order form already exists for the quote version", :premium do
      before { create(:order_form, quote_version:, organization:, customer: quote.customer) }

      it "does not create another order form" do
        expect { result }.not_to change(OrderForm, :count)
      end

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq(quote_version_id: ["value_already_exist"])
      end
    end

    context "when the quote version does not exist", :premium do
      let(:quote_version) { nil }

      it "returns a not found failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_version_not_found")
      end
    end
  end
end
