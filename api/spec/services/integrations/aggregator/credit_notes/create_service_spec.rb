# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::CreditNotes::CreateService do
  subject(:service_call) { described_class.call(credit_note: credit_note.reload) }

  let(:service) { described_class.new(credit_note: credit_note.reload) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/netsuite/creditnotes" }
  let(:add_on) { create(:add_on, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, billable_metric:) }

  let(:integration_collection_mapping1) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :fallback_item,
      settings: {external_id: "1", external_account_code: "11", external_name: ""}
    )
  end
  let(:integration_collection_mapping2) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :coupon,
      settings: {external_id: "2", external_account_code: "22", external_name: ""}
    )
  end
  let(:integration_collection_mapping3) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :subscription_fee,
      settings: {external_id: "3", external_account_code: "33", external_name: ""}
    )
  end
  let(:integration_collection_mapping4) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :minimum_commitment,
      settings: {external_id: "4", external_account_code: "44", external_name: ""}
    )
  end
  let(:integration_collection_mapping5) do
    create(
      :netsuite_collection_mapping,
      integration:,
      mapping_type: :tax,
      settings: {external_id: "5", external_account_code: "55", external_name: ""}
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
  let(:integration_mapping_bm) do
    create(
      :netsuite_mapping,
      integration:,
      mappable_type: "BillableMetric",
      mappable_id: billable_metric.id,
      settings: {external_id: "m2", external_account_code: "m22", external_name: ""}
    )
  end

  let(:invoice) do
    create(
      :invoice,
      customer:,
      organization:,
      coupons_amount_cents: 2000,
      prepaid_credit_amount_cents: 4000,
      credit_notes_amount_cents: 6000,
      taxes_amount_cents: 8000
    )
  end
  let(:credit_note) do
    create(
      :credit_note,
      customer:,
      invoice:,
      status: "finalized",
      organization:,
      coupons_adjustment_amount_cents: 2000,
      taxes_amount_cents: 8000
    )
  end
  let(:fee_sub) do
    create(
      :fee,
      invoice:
    )
  end
  let(:minimum_commitment_fee) do
    create(
      :minimum_commitment_fee,
      invoice:
    )
  end
  let(:charge_fee) do
    create(
      :charge_fee,
      invoice:,
      charge:,
      units: 2,
      precise_unit_amount: 4.12
    )
  end

  let(:credit_note_item3) { create(:credit_note_item, credit_note:, fee: charge_fee, amount_cents: 212) }

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "netsuite-tba"
    }
  end

  let(:params) do
    {
      "type" => "creditmemo",
      "isDynamic" => true,
      "columns" => {
        "tranid" => credit_note.number,
        "entity" => integration_customer.external_customer_id,
        "taxregoverride" => true,
        "taxdetailsoverride" => true,
        "otherrefnum" => credit_note.number,
        "custbody_ava_disable_tax_calculation" => true,
        "custbody_lago_id" => credit_note.id,
        "tranId" => credit_note.id
      },
      "lines" => [
        {
          "sublistId" => "item",
          "lineItems" => [
            {
              "item" => "m2",
              "account" => "m22",
              "quantity" => 1,
              "rate" => 2.12,
              "taxdetailsreference" => anything,
              "description" => charge_fee.item_name
            },
            {
              "item" => "2",
              "account" => "22",
              "quantity" => 1,
              "rate" => -20.0,
              "taxdetailsreference" => "coupon_item",
              "description" => description
            }
          ]
        }
      ],
      "options" => {
        "ignoreMandatoryFields" => false,
        "fullCreditNotePayload" => {
          "credit_note_payload" => hash_including(
            lago_id: credit_note.id,
            billing_entity_code: invoice.billing_entity.code,
            sequential_id: credit_note.sequential_id,
            number: credit_note.number,
            lago_invoice_id: invoice.id,
            invoice_number: invoice.number,
            issuing_date: credit_note.issuing_date&.iso8601,
            credit_status: credit_note.credit_status,
            refund_status: credit_note.refund_status,
            reason: credit_note.reason,
            description: credit_note.description,
            currency: credit_note.currency,
            total_amount_cents: credit_note.total_amount_cents,
            precise_total_amount_cents: credit_note.precise_total&.to_s,
            taxes_amount_cents: credit_note.taxes_amount_cents,
            precise_taxes_amount_cents: credit_note.precise_taxes_amount_cents&.to_s,
            sub_total_excluding_taxes_amount_cents: credit_note.sub_total_excluding_taxes_amount_cents,
            balance_amount_cents: credit_note.balance_amount_cents,
            credit_amount_cents: credit_note.credit_amount_cents,
            refund_amount_cents: credit_note.refund_amount_cents,
            offset_amount_cents: credit_note.offset_amount_cents,
            coupons_adjustment_amount_cents: credit_note.coupons_adjustment_amount_cents,
            taxes_rate: credit_note.taxes_rate,
            created_at: credit_note.created_at.iso8601,
            updated_at: credit_note.updated_at.iso8601,
            customer: hash_including(
              lago_id: customer.id,
              external_id: customer.external_id,
              name: customer.name,
              integration_customers: anything
            ),
            items: credit_note.items.map do |item|
              hash_including(
                lago_id: item.id
              )
            end,
            applied_taxes: anything
          )
        }
      }
    }
  end

  let(:description) { credit_note.invoice.credits.coupon_kind.map(&:item_name).join(",") }

  before do
    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)

    integration_customer
    charge
    credit_note
    integration_collection_mapping1
    integration_collection_mapping2
    integration_collection_mapping3
    integration_collection_mapping4
    integration_collection_mapping5
    integration_mapping_add_on
    integration_mapping_bm
    fee_sub
    minimum_commitment_fee
    charge_fee

    if credit_note
      credit_note_item3
      credit_note.reload
    end

    integration.sync_credit_notes = true
    integration.save!
  end

  describe "#call_async" do
    subject(:service_call_async) { described_class.new(credit_note:).call_async }

    context "when credit_note exists" do
      it "enqueues credit_note create job" do
        expect { service_call_async }.to enqueue_job(Integrations::Aggregator::CreditNotes::CreateJob)
      end
    end

    context "when credit_note does not exist" do
      let(:credit_note) { nil }

      it "returns an error" do
        result = service_call_async

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("credit_note_not_found")
      end
    end
  end

  describe "#call" do
    context "when integration_credit_note exists" do
      let(:integration_credit_note) do
        create(:integration_resource, integration:, syncable: credit_note, resource_type: "credit_note")
      end

      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        integration_credit_note
      end

      it "returns result without making an API call" do
        expect(lago_client).not_to have_received(:post_with_response)
        result = service_call

        expect(result).to be_success
        expect(result.external_id).to be_nil
      end
    end

    context "when service call is successful" do
      let(:response) { instance_double(Net::HTTPOK) }

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      context "when response is a hash" do
        context "when credit note is succesfully created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/credit_notes/success_hash_response.json")
            File.read(path)
          end

          it "returns external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to eq("e5a62e05-e192-489f-8965-e01b597b523b")
          end

          it "creates integration resource object" do
            expect { service_call }
              .to change(IntegrationResource, :count).by(1)

            integration_resource = IntegrationResource.order(created_at: :desc).first

            expect(integration_resource.syncable_id).to eq(credit_note.id)
            expect(integration_resource.syncable_type).to eq("CreditNote")
            expect(integration_resource.resource_type).to eq("credit_note")
          end

          it_behaves_like "throttles!", :anrok, :netsuite, :xero
        end

        context "when credit note is not created" do
          let(:body) do
            path = Rails.root.join("spec/fixtures/integration_aggregator/credit_notes/failure_hash_response.json")
            File.read(path)
          end

          it "does not return external id" do
            result = service_call

            expect(result).to be_success
            expect(result.external_id).to be(nil)
          end

          it "does not create integration resource object" do
            expect { service_call }.not_to change(IntegrationResource, :count)
          end

          it_behaves_like "throttles!", :anrok, :netsuite, :xero
        end
      end

      context "when response is a string" do
        let(:body) do
          path = Rails.root.join("spec/fixtures/integration_aggregator/credit_notes/success_string_response.json")
          File.read(path)
        end

        it "returns external id" do
          result = service_call

          expect(result).to be_success
          expect(result.external_id).to eq("456")
        end

        it "creates integration resource object" do
          expect { service_call }
            .to change(IntegrationResource, :count).by(1)

          integration_resource = IntegrationResource.order(created_at: :desc).first

          expect(integration_resource.syncable_id).to eq(credit_note.id)
          expect(integration_resource.syncable_type).to eq("CreditNote")
          expect(integration_resource.resource_type).to eq("credit_note")
        end

        it_behaves_like "throttles!", :anrok, :netsuite, :xero
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
        let(:error_code) { 500 }

        it "returns an error" do
          expect do
            service_call
          end.to raise_error(http_error)
        end

        it "enqueues a SendWebhookJob" do
          expect { service_call }.to have_enqueued_job(SendWebhookJob).and raise_error(http_error)
        end
      end

      context "when it is a client error" do
        let(:error_code) { 400 }

        it "does not return an error" do
          expect { service_call }.not_to raise_error
        end

        it "enqueues a SendWebhookJob" do
          expect { service_call }.to have_enqueued_job(SendWebhookJob)
        end

        it_behaves_like "throttles!", :anrok, :netsuite, :xero
      end
    end

    context "when there is payload error" do
      let(:integration) { create(:xero_integration, organization:) }
      let(:integration_customer) { create(:xero_customer, integration:, customer:) }
      let(:lago_client) { instance_double(LagoHttpClient::Client) }
      let(:endpoint) { "https://api.nango.dev/v1/xero/creditnotes" }
      let(:integration_collection_mapping1) { nil }
      let(:integration_collection_mapping2) { nil }
      let(:integration_collection_mapping3) { nil }
      let(:integration_collection_mapping4) { nil }
      let(:integration_collection_mapping5) { nil }
      let(:integration_collection_mapping6) { nil }
      let(:integration_mapping_add_on) { nil }
      let(:integration_mapping_bm) { nil }
      let(:response) { instance_double(Net::HTTPOK) }
      let(:headers) do
        {
          "Connection-Id" => integration.connection_id,
          "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
          "Provider-Config-Key" => "xero"
        }
      end
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/credit_notes/success_hash_response.json")
        File.read(path)
      end

      before do
        allow(lago_client).to receive(:post_with_response).with(params, headers).and_return(response)
        allow(response).to receive(:body).and_return(body)
      end

      it "sends error webhook" do
        expect { service_call }.to have_enqueued_job(SendWebhookJob)
      end

      it "returns result" do
        expect(service_call).to be_a(BaseService::Result)
      end

      it_behaves_like "throttles!", :anrok, :netsuite, :xero
    end
  end
end
