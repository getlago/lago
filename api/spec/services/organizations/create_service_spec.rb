# frozen_string_literal: true

require "rails_helper"

RSpec.describe Organizations::CreateService do
  describe "#call" do
    subject(:service_result) { described_class.call(params) }

    context "with valid params" do
      let(:params) do
        {
          name: Faker::Company.name,
          document_numbering: "per_customer",
          premium_integrations: ["okta"]
        }
      end

      it "creates an organization with provided params" do
        expect { service_result }.to change(Organization, :count).by(1)

        expect(service_result.organization)
          .to be_persisted
          .and have_attributes(
            name: params[:name],
            document_numbering: params[:document_numbering],
            premium_integrations: params[:premium_integrations]
          )
      end

      it "creates an API key for created organization" do
        expect { service_result }.to change(ApiKey, :count).by(1)

        expect(service_result.organization.api_keys).to all(
          be_persisted.and(have_attributes(organization: service_result.organization))
        )
      end

      context "when LAGO_CLICKHOUSE_ENABLED is set" do
        around do |example|
          previous_value = ENV["LAGO_CLICKHOUSE_ENABLED"]
          ENV["LAGO_CLICKHOUSE_ENABLED"] = "true"
          example.run
        ensure
          ENV["LAGO_CLICKHOUSE_ENABLED"] = previous_value
        end

        context "when LAGO_DEFAULT_EVENT_STORE is clickhouse" do
          around do |example|
            previous_value = ENV["LAGO_DEFAULT_EVENT_STORE"]
            ENV["LAGO_DEFAULT_EVENT_STORE"] = "clickhouse"
            example.run
          ensure
            ENV["LAGO_DEFAULT_EVENT_STORE"] = previous_value
          end

          it "enables clickhouse_events_store" do
            expect(service_result.organization.reload.clickhouse_events_store).to be true
            expect(service_result.organization.clickhouse_deduplication_enabled).to be true
          end
        end

        context "when LAGO_DEFAULT_EVENT_STORE is not clickhouse" do
          around do |example|
            previous_value = ENV["LAGO_DEFAULT_EVENT_STORE"]
            ENV["LAGO_DEFAULT_EVENT_STORE"] = "postgres"
            example.run
          ensure
            ENV["LAGO_DEFAULT_EVENT_STORE"] = previous_value
          end

          it "leaves clickhouse_events_store disabled" do
            expect(service_result.organization.reload.clickhouse_events_store).to be false
            expect(service_result.organization.clickhouse_deduplication_enabled).to be false
          end
        end
      end

      context "when LAGO_CLICKHOUSE_ENABLED is not set" do
        around do |example|
          previous_value = ENV["LAGO_CLICKHOUSE_ENABLED"]
          ENV.delete("LAGO_CLICKHOUSE_ENABLED")
          example.run
        ensure
          ENV["LAGO_CLICKHOUSE_ENABLED"] = previous_value
        end

        it "leaves clickhouse_events_store disabled" do
          expect(service_result.organization.reload.clickhouse_events_store).to be false
          expect(service_result.organization.clickhouse_deduplication_enabled).to be false
        end
      end

      context "when document_numbering is per_customer" do
        let(:params) do
          {
            name: Faker::Company.name,
            document_numbering: "per_customer"
          }
        end

        it "creates a billing entity for created organization" do
          expect { service_result }.to change(BillingEntity, :count).by(1)

          billing_entity = service_result.organization.billing_entities.first
          expect(billing_entity).to have_attributes(
            id: service_result.organization.id,
            organization: service_result.organization,
            name: service_result.organization.name,
            code: service_result.organization.name.parameterize(separator: "_"),
            document_number_prefix: service_result.organization.document_number_prefix,
            eu_tax_management: false,
            document_numbering: "per_customer"
          )
        end
      end

      context "when document_numbering is per_organization" do
        let(:params) do
          {
            name: Faker::Company.name,
            document_numbering: "per_organization",
            code: "this_code_will_be_used_for_billing_entity"
          }
        end

        it "creates billing_entity with number per_billing_entity" do
          expect { service_result }.to change(BillingEntity, :count).by(1)

          billing_entity = service_result.organization.billing_entities.first
          expect(billing_entity).to have_attributes(
            id: service_result.organization.id,
            organization: service_result.organization,
            name: service_result.organization.name,
            code: "this_code_will_be_used_for_billing_entity",
            document_numbering: "per_billing_entity"
          )
        end
      end
    end

    context "with invalid params" do
      let(:params) { {} }

      it "does not create an organization" do
        expect { service_result }.not_to change(Organization, :count)
      end

      it "does not create an API key" do
        expect { service_result }.not_to change(ApiKey, :count)
      end

      it "returns an error" do
        expect(service_result).not_to be_success
        expect(service_result.error).to be_a(BaseService::ValidationFailure)
        expect(service_result.error.messages[:name]).to eq(["value_is_mandatory"])
      end
    end
  end
end
