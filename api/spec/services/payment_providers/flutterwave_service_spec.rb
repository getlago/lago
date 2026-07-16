# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::FlutterwaveService do
  subject(:flutterwave_service) { described_class.new }

  include_context "with mocked security logger"

  let(:organization) { create(:organization) }

  describe "#create_or_update" do
    let(:args) do
      {
        organization: organization,
        code: "flutterwave_1",
        name: "Flutterwave Provider",
        secret_key: "FLWSECK_TEST-test_secret_key",
        success_redirect_url: "https://example.com/success"
      }
    end

    context "when creating a new provider" do
      it "creates a new flutterwave provider" do
        result = flutterwave_service.create_or_update(**args)

        expect(result).to be_success
        expect(result.flutterwave_provider).to be_a(PaymentProviders::FlutterwaveProvider)
        expect(result.flutterwave_provider.organization_id).to eq(organization.id)
        expect(result.flutterwave_provider.code).to eq("flutterwave_1")
        expect(result.flutterwave_provider.name).to eq("Flutterwave Provider")
        expect(result.flutterwave_provider.secret_key).to eq("FLWSECK_TEST-test_secret_key")
        expect(result.flutterwave_provider.success_redirect_url).to eq("https://example.com/success")
      end

      it_behaves_like "produces a security log", "integration.created" do
        before { flutterwave_service.create_or_update(**args) }
      end
    end

    context "when updating an existing provider" do
      let(:existing_provider) do
        create(
          :flutterwave_provider,
          organization: organization,
          code: "flutterwave_1",
          name: "Old Name",
          secret_key: "old_secret_key",
          success_redirect_url: "https://old.example.com"
        )
      end

      before { existing_provider }

      it "updates the existing provider" do
        result = flutterwave_service.create_or_update(**args)

        expect(result).to be_success
        expect(result.flutterwave_provider.id).to eq(existing_provider.id)
        expect(result.flutterwave_provider.name).to eq("Flutterwave Provider")
        expect(result.flutterwave_provider.secret_key).to eq("FLWSECK_TEST-test_secret_key")
        expect(result.flutterwave_provider.success_redirect_url).to eq("https://example.com/success")
      end

      it_behaves_like "produces a security log", "integration.updated" do
        before { flutterwave_service.create_or_update(**args) }
      end

      context "when code is updated" do
        let(:customer) { create(:customer, organization: organization, payment_provider_code: "flutterwave_1") }
        let!(:flutterwave_customer) do
          create(:flutterwave_customer, customer: customer, payment_provider: existing_provider)
        end

        let(:args) do
          {
            organization: organization,
            id: existing_provider.id,
            code: "flutterwave_2",
            name: "Updated Flutterwave Provider",
            secret_key: "FLWSECK_TEST-updated_secret_key",
            success_redirect_url: "https://updated.example.com"
          }
        end

        it "updates the provider and associated customer codes" do
          result = flutterwave_service.create_or_update(**args)

          expect(result).to be_success
          expect(result.flutterwave_provider.code).to eq("flutterwave_2")
          flutterwave_customer.reload
          expect(flutterwave_customer.customer.payment_provider_code).to eq("flutterwave_2")
        end
      end
    end

    context "when partial update with only specific fields" do
      let(:existing_provider) do
        create(
          :flutterwave_provider,
          organization: organization,
          code: "flutterwave_1",
          name: "Original Name",
          secret_key: "original_secret_key",
          success_redirect_url: "https://original.example.com"
        )
      end

      before { existing_provider }

      it "updates only the provided fields" do
        partial_args = {
          organization: organization,
          id: existing_provider.id,
          name: "Updated Name Only"
        }

        result = flutterwave_service.create_or_update(**partial_args)

        expect(result).to be_success
        expect(result.flutterwave_provider.name).to eq("Updated Name Only")
        expect(result.flutterwave_provider.secret_key).to eq("original_secret_key") # unchanged
        expect(result.flutterwave_provider.success_redirect_url).to eq("https://original.example.com") # unchanged
      end
    end

    context "when validation fails" do
      let(:args) do
        {
          organization: organization,
          code: "flutterwave_test",
          name: "", # Invalid empty name
          secret_key: "FLWSECK_TEST-test_secret_key"
        }
      end

      it "returns a failure result with validation errors" do
        result = flutterwave_service.create_or_update(**args)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
      end
    end

    context "when finding existing provider by code" do
      let(:existing_provider) do
        create(
          :flutterwave_provider,
          organization: organization,
          code: "flutterwave_1"
        )
      end

      before { existing_provider }

      it "finds and updates the existing provider by code" do
        update_args = args.merge(code: "flutterwave_1", name: "Updated via Code")

        result = flutterwave_service.create_or_update(**update_args)

        expect(result).to be_success
        expect(result.flutterwave_provider.id).to eq(existing_provider.id)
        expect(result.flutterwave_provider.name).to eq("Updated via Code")
      end
    end
  end
end
