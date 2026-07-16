# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Taxes::CreditNotes::CreateService do
  subject(:service_call) { described_class.call(credit_note:) }

  let(:integration) { create(:anrok_integration, organization:) }
  let(:integration_customer) { create(:anrok_customer, integration:, customer:, external_customer_id: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
  let(:add_on) { create(:add_on, organization:) }
  let(:add_on_two) { create(:add_on, organization:) }
  let(:current_time) { Time.current }

  let(:integration_collection_mapping1) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end
  let(:integration_mapping_add_on) do
    create(
      :netsuite_mapping,
      integration:,
      mappable_type: "AddOn",
      mappable_id: add_on.id,
      settings: {external_id: "m1", external_account_code: "m11", external_name: ""}
    )
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:
    )
  end
  let(:fee_add_on) do
    create(
      :fee,
      invoice:,
      add_on:,
      created_at: current_time - 3.seconds
    )
  end
  let(:fee_add_on_two) do
    create(
      :fee,
      invoice:,
      add_on: add_on_two,
      created_at: current_time - 2.seconds
    )
  end
  let(:credit_note) do
    create(
      :credit_note,
      customer:,
      invoice:,
      status: "finalized",
      organization:
    )
  end

  let(:credit_note_item1) do
    create(:credit_note_item, credit_note:, fee: fee_add_on, amount_cents: fee_add_on.amount_cents)
  end
  let(:credit_note_item2) do
    create(:credit_note_item, credit_note:, fee: fee_add_on_two, amount_cents: fee_add_on_two.amount_cents)
  end

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "anrok"
    }
  end

  let(:params) do
    [
      {
        "id" => "cn_#{credit_note.id}",
        "issuing_date" => credit_note.issuing_date,
        "currency" => credit_note.currency,
        "contact" => {
          "external_id" => customer.external_id,
          "name" => customer.name,
          "address_line_1" => customer.address_line1,
          "city" => customer.city,
          "zip" => customer.zipcode,
          "country" => customer.country,
          "taxable" => false,
          "tax_number" => nil
        },
        "fees" => [
          {
            "item_id" => fee_add_on.item_id,
            "item_code" => "m1",
            "amount_cents" => -200
          },
          {
            "item_id" => fee_add_on_two.item_id,
            "item_code" => "1",
            "amount_cents" => -200
          }
        ],
        "tax_date" => credit_note.invoice.issuing_date
      }
    ]
  end

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)

    integration_customer
    integration_collection_mapping1
    integration_mapping_add_on
    fee_add_on
    fee_add_on_two
    credit_note_item1
    credit_note_item2
  end

  describe "#call" do
    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when transaction is created and taxes are successfully fetched for credit note" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
          File.read(path)
        end

        it "returns fees" do
          result = service_call

          expect(result).to be_success
          expect(result.fees.first.tax_breakdown.first.rate).to eq("0.10")
          expect(result.fees.first.tax_breakdown.first.name).to eq("GST/HST")
          expect(result.fees.first.tax_breakdown.last.name).to eq("Reverse charge")
          expect(result.fees.first.tax_breakdown.last.type).to eq("exempt")
          expect(result.fees.first.tax_breakdown.last.rate).to eq("0.00")
        end

        it "sets integration customer external id" do
          service_call

          expect(integration_customer.reload.external_customer_id).to eq(customer.external_id)
        end
      end

      context "when taxes are not successfully reported" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
          File.read(path)
        end

        it "does not return fees" do
          result = service_call

          expect(result).not_to be_success
          expect(result.fees).to be(nil)
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("taxDateTooFarInFuture")
        end

        it "delivers an error webhook" do
          expect { service_call }.to enqueue_job(SendWebhookJob)
            .with(
              "customer.tax_provider_error",
              customer,
              provider: "anrok",
              provider_code: integration.code,
              provider_error: {
                message: "Service failure",
                error_code: "taxDateTooFarInFuture"
              }
            )
        end

        it "does not set integration customer external id" do
          service_call

          expect(integration_customer.reload.external_customer_id).to eq(nil)
        end
      end
    end

    context "when service call is not successful" do
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/error_response.json")
        File.read(path)
      end

      let(:http_error) { LagoHttpClient::HttpError.new(error_code, body, nil) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_raise(http_error)
      end

      context "when it is a server error" do
        let(:error_code) { Faker::Number.between(from: 500, to: 599) }

        it "returns an error" do
          result = service_call

          expect(result).not_to be_success
          expect(result.fees).to be(nil)
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("action_script_runtime_error")
        end
      end
    end
  end
end
