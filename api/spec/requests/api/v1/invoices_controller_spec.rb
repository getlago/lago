# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::InvoicesController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }
  let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }

  before { tax }

  describe "POST /api/v1/invoices" do
    subject { post_with_token(organization, "/api/v1/invoices", {invoice: create_params}) }

    let(:add_on_first) { create(:add_on, code: "first", organization:) }
    let(:add_on_second) { create(:add_on, code: "second", amount_cents: 400, organization:) }
    let(:customer_external_id) { customer.external_id }
    let(:invoice_display_name) { "Invoice item #1" }
    let(:create_params) do
      {
        external_customer_id: customer_external_id,
        currency: "EUR",
        fees: [
          {
            add_on_code: add_on_first.code,
            invoice_display_name:,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123",
            tax_codes: [tax.code]
          },
          {
            add_on_code: add_on_second.code
          }
        ],
        invoice_custom_section: {invoice_custom_section_codes: [section_1.code]}
      }
    end

    include_examples "requires API permission", "invoice", "write"

    it "creates an invoice" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoice]).to include(
        lago_id: String,
        issuing_date: Time.current.to_date.to_s,
        invoice_type: "one_off",
        fees_amount_cents: 2800,
        taxes_amount_cents: 560,
        total_amount_cents: 3360,
        currency: "EUR"
      )

      fee = json[:invoice][:fees].find { |f| f[:item][:code] == "first" }

      expect(fee[:item][:invoice_display_name]).to eq(invoice_display_name)
      expect(json[:invoice][:applied_taxes][0][:tax_code]).to eq(tax.code)
      expect(json[:invoice][:applied_invoice_custom_sections].size).to eq(1)
      expect(json[:invoice][:applied_invoice_custom_sections].first[:code]).to eq(section_1.code)
    end

    context "when customer does not exist" do
      let(:customer_external_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when add_on does not exist" do
      let(:create_params) do
        {
          external_customer_id: customer_external_id,
          currency: "EUR",
          fees: [
            {
              add_on_code: add_on_first.code,
              unit_amount_cents: 1200,
              units: 2,
              description: "desc-123"
            },
            {
              add_on_code: "invalid"
            }
          ]
        }
      end

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when skip_psp is true" do
      let(:create_params) do
        {
          external_customer_id: customer_external_id,
          currency: "EUR",
          skip_psp: true,
          fees: [
            {
              add_on_code: add_on_first.code,
              unit_amount_cents: 1200,
              units: 2
            }
          ]
        }
      end

      it "returns a success" do
        subject
        expect(response).to have_http_status(:success)
      end
    end

    context "with a purchase_order_number" do
      let(:create_params) do
        {
          external_customer_id: customer_external_id,
          currency: "EUR",
          purchase_order_number: "  PO-12345  ",
          fees: [
            {
              add_on_code: add_on_first.code,
              unit_amount_cents: 1200,
              units: 2
            }
          ]
        }
      end

      it "creates an invoice with the normalized purchase order number" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice][:purchase_order_number]).to eq("PO-12345")
      end
    end

    context "when multi_entity_billing feature flag is enabled" do
      let(:other_billing_entity) { create(:billing_entity, organization:) }

      before do
        organization.enable_feature_flag!(:multi_entity_billing)
        create(:tax, :applied_to_billing_entity, billing_entity: other_billing_entity, organization:, rate: 20)
      end

      context "with a known billing_entity_code" do
        let(:create_params) do
          {
            external_customer_id: customer_external_id,
            currency: "EUR",
            billing_entity_code: other_billing_entity.code,
            fees: [{add_on_code: add_on_first.code, unit_amount_cents: 1200, units: 2}]
          }
        end

        it "stamps the invoice with the resolved billing entity" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice][:billing_entity_code]).to eq(other_billing_entity.code)
        end
      end

      context "with an unknown billing_entity_code" do
        let(:create_params) do
          {
            external_customer_id: customer_external_id,
            currency: "EUR",
            billing_entity_code: "unknown_code",
            fees: [{add_on_code: add_on_first.code, unit_amount_cents: 1200, units: 2}]
          }
        end

        it "returns a not found error" do
          subject

          expect(response).to be_not_found_error("billing_entity")
        end
      end

      context "without billing_entity_code" do
        let(:create_params) do
          {
            external_customer_id: customer_external_id,
            currency: "EUR",
            fees: [{add_on_code: add_on_first.code, unit_amount_cents: 1200, units: 2}]
          }
        end

        it "stamps the invoice with the customer's billing entity" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice][:billing_entity_code]).to eq(customer.billing_entity.code)
        end
      end
    end

    context "when multi_entity_billing feature flag is disabled" do
      let(:other_billing_entity) { create(:billing_entity, organization:) }
      let(:create_params) do
        {
          external_customer_id: customer_external_id,
          currency: "EUR",
          billing_entity_code: other_billing_entity.code,
          fees: [{add_on_code: add_on_first.code, unit_amount_cents: 1200, units: 2}]
        }
      end

      it "ignores billing_entity_code and falls back to the customer's billing entity" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice][:billing_entity_code]).to eq(customer.billing_entity.code)
      end
    end
  end

  describe "PUT /api/v1/invoices/:id" do
    subject do
      put_with_token(organization, "/api/v1/invoices/#{invoice_id}", {invoice: update_params})
    end

    let(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }

    let(:update_params) do
      {payment_status: "succeeded"}
    end

    include_examples "requires API permission", "invoice", "write"

    it "updates an invoice" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoice][:lago_id]).to eq(invoice.id)
      expect(json[:invoice][:payment_status]).to eq("succeeded")
    end

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with metadata" do
      let(:update_params) do
        {
          metadata: [
            {
              key: "Hello",
              value: "Hi"
            }
          ]
        }
      end

      it "returns a success" do
        subject

        metadata = json[:invoice][:metadata]
        expect(response).to have_http_status(:success)

        expect(json[:invoice][:lago_id]).to eq(invoice.id)

        expect(metadata).to be_present
        expect(metadata.first[:key]).to eq("Hello")
        expect(metadata.first[:value]).to eq("Hi")
      end
    end
  end

  describe "GET /api/v1/invoices/:id" do
    subject { get_with_token(organization, "/api/v1/invoices/#{invoice_id}") }

    let(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }

    include_examples "requires API permission", "invoice", "read"

    it "returns an invoice" do
      charge_filter = create(:charge_filter)
      create(:fee, invoice_id: invoice.id, charge_filter:)

      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoice]).to include(
        lago_id: invoice.id,
        payment_status: invoice.payment_status,
        status: invoice.status,
        prepaid_credit_amount_cents: 0,
        prepaid_granted_credit_amount_cents: nil,
        prepaid_purchased_credit_amount_cents: nil,
        customer: Hash,
        subscriptions: [],
        credits: [],
        applied_taxes: [],
        applied_invoice_custom_sections: []
      )
      expect(json[:invoice][:fees].first).to include(lago_charge_filter_id: charge_filter.id)
    end

    context "when customer has an integration customer" do
      let!(:netsuite_customer) { create(:netsuite_customer, customer:) }

      it "returns an invoice with customer having integration customers" do
        subject

        expect(json[:invoice][:customer][:integration_customers].first).to include(lago_id: netsuite_customer.id)
      end
    end

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoices belongs to an other organization" do
      let(:invoice) { create(:invoice) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoice has a fee for a deleted billable metric" do
      let(:billable_metric) { create(:billable_metric, :deleted) }
      let(:billable_metric_filter) { create(:billable_metric_filter, :deleted, billable_metric:) }
      let(:charge_filter) do
        create(:charge_filter, :deleted, charge:, properties: {amount: "10"})
      end
      let(:charge_filter_value) do
        create(
          :charge_filter_value,
          :deleted,
          charge_filter:,
          billable_metric_filter:,
          values: [billable_metric_filter.values.first]
        )
      end
      let(:fee) { create(:charge_fee, invoice:, charge_filter:, charge:) }

      let(:charge) do
        create(:standard_charge, :deleted, billable_metric:)
      end

      before do
        charge
        fee
        charge_filter_value
      end

      it "returns the invoice with the deleted resources" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice]).to include(
          lago_id: invoice.id,
          payment_status: invoice.payment_status,
          status: invoice.status,
          customer: Hash,
          subscriptions: [],
          credits: [],
          applied_taxes: []
        )

        json_fee = json[:invoice][:fees].first
        expect(json_fee[:lago_charge_filter_id]).to eq(charge_filter.id)
        expect(json_fee[:item]).to include(
          type: "charge",
          code: billable_metric.code,
          name: billable_metric.name
        )
      end
    end
  end

  describe "GET /api/v1/invoices" do
    it_behaves_like "an invoice index endpoint" do
      subject { get_with_token(organization, "/api/v1/invoices", params) }

      [:external_customer_id, :customer_external_id].each do |param_name|
        context "with #{param_name} params" do
          let(:params) { {param_name => external_customer_id} }

          let!(:matching_invoice) { create(:invoice, customer:, organization:) }
          let(:external_customer_id) { customer.external_id }

          before do
            another_customer = create(:customer, organization:)
            create(:invoice, customer: another_customer, organization:)
          end

          it "returns invoices of the customer" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:invoices].count).to eq(1)
            expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
          end

          context "with deleted customer" do
            let(:params) { {external_customer_id:} }
            let(:customer) { create(:customer, :deleted, organization:) }
            let(:external_customer_id) { customer.external_id }
            let!(:matching_invoice) { create(:invoice, customer:, organization:) }

            it "returns the invoices of the customer" do
              subject

              expect(response).to have_http_status(:success)
              expect(json[:invoices].count).to eq(1)
              expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
              expect(json[:invoices].first[:customer][:lago_id]).to eq(customer.id)
            end
          end
        end
      end
    end

    context "with N+1 query detection on customer associations", bullet: {n_plus_one_query: true, unused_eager_loading: false} do
      let(:other_billing_entity) { create(:billing_entity, organization:) }

      before do
        [customer.billing_entity, other_billing_entity].each do |billing_entity|
          invoice_customer = create(
            :customer,
            organization:,
            billing_entity:,
            payment_provider: "stripe",
            payment_provider_code: "stripe_code"
          )
          create(:stripe_customer, customer: invoice_customer)
          create(:netsuite_customer, customer: invoice_customer)
          create(:hubspot_customer, customer: invoice_customer)
          create(:customer_metadata, customer: invoice_customer, organization:)

          create(:invoice, customer: invoice_customer, organization:, billing_entity:)
        end
      end

      it "does not trigger N+1 queries on customer and nested associations" do
        get_with_token(organization, "/api/v1/invoices", {})

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(2)
        json[:invoices].each do |invoice|
          expect(invoice[:customer][:billing_configuration][:provider_customer_id]).to be_present
          expect(invoice[:customer][:integration_customers]).to be_present
          expect(invoice[:customer][:metadata]).to be_present
        end
      end
    end

    context "with unknown params" do
      before do
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        create(:invoice, :draft, customer:, organization:)
        create(:invoice, customer:, organization:)
      end

      it "ignores unknown params for caching" do
        # First request populates the cache
        get_with_token(organization, "/api/v1/invoices", page: 1, per_page: 1)
        expect(json[:meta][:total_count]).to eq(2)

        # Add a third invoice
        create(:invoice, customer:, organization:)

        # Request with unknown param should return cached count (2), not fresh count (3)
        get_with_token(organization, "/api/v1/invoices", page: 1, per_page: 1, unknown_param: "value")
        expect(json[:meta][:total_count]).to eq(2)
      end
    end
  end

  describe "PUT /api/v1/invoices/:id/refresh" do
    subject { put_with_token(organization, "/api/v1/invoices/#{invoice_id}/refresh") }

    let(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoice is draft" do
      let(:invoice) { create(:invoice, :draft, customer:, organization:) }

      include_examples "requires API permission", "invoice", "write"

      it "updates the invoice" do
        expect { subject }.to change { invoice.reload.updated_at }
      end

      it "returns the invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice][:lago_id]).to eq(invoice.id)
      end
    end

    context "when invoice is finalized" do
      let(:invoice) { create(:invoice, customer:, organization:) }

      it "does not update the invoice" do
        expect { subject }.not_to change { invoice.reload.updated_at }
      end

      it "returns the invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice][:lago_id]).to eq(invoice.id)
      end
    end
  end

  describe "PUT /api/v1/invoices/:id/finalize" do
    subject { put_with_token(organization, "/api/v1/invoices/#{invoice_id}/finalize") }

    let(:invoice) { create(:invoice, :draft, customer:, organization:) }
    let(:invoice_id) { invoice.id }

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoice is not draft" do
      let(:invoice) { create(:invoice, customer:, status: :finalized, organization:) }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoice is draft" do
      include_examples "requires API permission", "invoice", "write"

      it "finalizes the invoice" do
        expect { subject }.to change { invoice.reload.status }.from("draft").to("finalized")
      end

      it "returns the invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice][:lago_id]).to eq(invoice.id)
      end
    end
  end

  describe "POST /api/v1/invoices/:id/void" do
    subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/void", params) }

    let!(:invoice) { create(:invoice, status:, payment_status:, customer:, organization:) }
    let(:invoice_id) { invoice.id }
    let(:status) { :finalized }
    let(:payment_status) { :pending }
    let(:params) { {} }

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoice is draft" do
      let(:status) { :draft }

      it "returns a method not allowed error" do
        subject
        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    context "when invoice is voided" do
      let(:status) { :voided }

      it "returns a method not allowed error" do
        subject
        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    context "when invoice is finalized" do
      let(:status) { :finalized }

      context "when the payment status is succeeded" do
        let(:payment_status) { :succeeded }

        it "voids the invoice" do
          expect { subject }.to change { invoice.reload.status }.from("finalized").to("voided")
        end
      end

      context "when the payment status is not succeeded" do
        let(:payment_status) { [:pending, :failed].sample }

        include_examples "requires API permission", "invoice", "write"

        it "voids the invoice" do
          expect { subject }.to change { invoice.reload.status }.from("finalized").to("voided")
        end

        it "returns the invoice" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice][:lago_id]).to eq(invoice.id)
        end
      end
    end

    context "when passing credit note parameters", :premium do
      let(:credit_amount) { 0 }
      let(:refund_amount) { 0 }
      let(:params) { {generate_credit_note: true, credit_amount: credit_amount, refund_amount: refund_amount} }

      it "calls the void service with all parameters" do
        allow(Invoices::VoidService).to receive(:call).with(
          invoice: instance_of(Invoice),
          params: hash_including(
            generate_credit_note: true,
            credit_amount: credit_amount,
            refund_amount: refund_amount
          )
        ).and_call_original

        subject

        expect(Invoices::VoidService).to have_received(:call).with(
          invoice: instance_of(Invoice),
          params: hash_including(
            generate_credit_note: true,
            credit_amount: credit_amount,
            refund_amount: refund_amount
          )
        )
        expect(response).to have_http_status(:success)
        expect(json[:invoice][:lago_id]).to eq(invoice.id)
        expect(json[:invoice][:status]).to eq("voided")
        expect(json[:invoice][:voided_at]).not_to be_nil
      end
    end
  end

  describe "POST /api/v1/invoices/:id/lose_dispute" do
    subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/lose_dispute") }

    let(:invoice) { create(:invoice, status:, customer:, organization:) }
    let(:invoice_id) { invoice.id }
    let(:status) { :draft }

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoice exists" do
      let(:invoice) { create(:invoice, customer:, organization:, status:) }

      context "when invoice is finalized" do
        let(:status) { :finalized }

        include_examples "requires API permission", "invoice", "write"

        it "marks the dispute as lost" do
          expect { subject }.to change { invoice.reload.payment_dispute_lost_at }.from(nil)
        end

        it "returns the invoice" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice][:lago_id]).to eq(invoice.id)
        end
      end

      context "when invoice is voided" do
        let(:status) { :voided }

        it "marks the dispute as lost" do
          expect { subject }.to change { invoice.reload.payment_dispute_lost_at }.from(nil)
        end

        it "returns the invoice" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice][:lago_id]).to eq(invoice.id)
        end
      end

      context "when invoice is draft" do
        let(:status) { :draft }

        it "returns method not allowed error" do
          subject
          expect(response).to have_http_status(:method_not_allowed)
        end
      end

      context "when invoice is generating" do
        let(:status) { :generating }

        it "returns not found error" do
          subject
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe "POST /api/v1/invoices/:id/download_pdf" do
    ["download", "download_pdf"].each do |route|
      subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/#{route}") }

      let(:invoice) { create(:invoice, customer:, organization:, status: invoice_status) }
      let(:invoice_status) { :finalized }
      let(:invoice_id) { invoice.id }

      include_examples "requires API permission", "invoice", "write"

      context "with /#{route}" do
        context "without generated pdf" do
          before do
            allow(Invoices::GeneratePdfJob).to receive(:perform_later)
          end

          it "calls generate pdf async" do
            subject

            expect(Invoices::GeneratePdfJob).to have_received(:perform_later)
          end
        end

        context "when generated pdf" do
          before do
            allow(Invoices::GeneratePdfJob).to receive(:perform_later)

            invoice.file.attach(
              io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
              filename: "invoice.pdf",
              content_type: "application/pdf"
            )
          end

          it "does not regenerate" do
            subject

            expect(Invoices::GeneratePdfJob).not_to have_received(:perform_later)
          end
        end

        context "when invoice is draft" do
          let(:invoice_status) { :draft }

          it "returns not found" do
            subject
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end

  describe "POST /api/v1/invoices/:id/download_xml" do
    subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/download_xml") }

    let(:invoice) { create(:invoice, customer:, organization:, status: invoice_status) }
    let(:invoice_status) { :finalized }
    let(:invoice_id) { invoice.id }

    include_examples "requires API permission", "invoice", "write"

    context "without generated pdf" do
      before do
        allow(Invoices::GenerateXmlJob).to receive(:perform_later)
      end

      it "calls generate pdf async" do
        subject

        expect(Invoices::GenerateXmlJob).to have_received(:perform_later)
      end
    end

    context "with generated pdf" do
      before do
        allow(Invoices::GenerateXmlJob).to receive(:perform_later)

        invoice.xml_file.attach(
          io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.xml"))),
          filename: "invoice.xml",
          content_type: "application/xml"
        )
      end

      it "does not regenerate" do
        subject

        expect(Invoices::GenerateXmlJob).not_to have_received(:perform_later)
      end
    end

    context "when invoice is draft" do
      let(:invoice_status) { :draft }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/invoices/:id/retry_payment" do
    subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/retry_payment", payment_params) }

    let(:payment_params) { {} }
    let(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }
    let(:retry_service) { instance_double(Invoices::Payments::RetryService) }

    before do
      allow(Invoices::Payments::RetryService).to receive(:new).and_return(retry_service)
      allow(retry_service).to receive(:call).and_return(BaseService::Result.new)
    end

    include_examples "requires API permission", "invoice", "write"

    it "calls retry service" do
      subject

      expect(response).to have_http_status(:success)
      expect(retry_service).to have_received(:call)
    end

    context "with payment method" do
      let(:payment_params) do
        {
          payment_method: {
            payment_method_type: "manual"
          }
        }
      end

      it "calls retry service" do
        subject

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(retry_service).to have_received(:call)
        end
      end
    end

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoices belongs to an other organization" do
      let(:invoice) { create(:invoice) }

      it "returns not found" do
        subject

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/invoices/:id/retry" do
    subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/retry") }

    let!(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }
    let(:retry_service) { instance_double(Invoices::RetryService) }
    let(:result) { BaseService::Result.new }

    before do
      result.invoice = invoice

      allow(Invoices::RetryService).to receive(:new).and_return(retry_service)
      allow(retry_service).to receive(:call).and_return(result)
    end

    include_examples "requires API permission", "invoice", "write"

    it "calls retry service" do
      subject

      expect(response).to have_http_status(:success)
      expect(retry_service).to have_received(:call)
    end

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when invoices belongs to an other organization" do
      let(:invoice) { create(:invoice) }

      it "returns not found" do
        subject

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/v1/invoices/:id/sync_salesforce_id" do
    subject { put_with_token(organization, "/api/v1/invoices/#{invoice_id}/sync_salesforce_id") }

    let!(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }
    let(:result) { BaseService::Result.new }

    before do
      result.invoice = invoice
      allow(Invoices::SyncSalesforceIdService).to receive(:call).and_return(result)
    end

    context "when invoice exists" do
      include_examples "requires API permission", "invoice", "write"

      it "calls sync salesforce id service" do
        subject

        expect(response).to have_http_status(:success)
        expect(Invoices::SyncSalesforceIdService).to have_received(:call)
      end
    end

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/invoices/:id/payment_url" do
    subject { post_with_token(organization, "/api/v1/invoices/#{invoice_id}/payment_url") }

    let!(:invoice) { create(:invoice, customer:, organization:) }
    let(:invoice_id) { invoice.id }
    let(:organization) { create(:organization) }
    let(:stripe_provider) { create(:stripe_provider, organization:, code:) }
    let(:customer) { create(:customer, organization:, payment_provider_code: code) }
    let(:code) { "stripe_1" }

    before do
      create(
        :stripe_customer,
        customer_id: customer.id,
        payment_provider: stripe_provider
      )

      customer.update!(payment_provider: "stripe")

      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example.com"})
    end

    context "when invoice exists" do
      include_examples "requires API permission", "invoice", "write"

      it "returns the generated payment url" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice_payment_details][:payment_url]).to eq("https://example.com")
      end
    end

    context "when invoice does not exist" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/invoices/preview", :premium do
    subject { post_with_token(organization, "/api/v1/invoices/preview", preview_params) }

    let(:plan) { create(:plan, organization:) }
    let(:preview_params) do
      {
        customer: {
          name: "test 1",
          currency: "EUR",
          tax_identification_number: "123456789"
        },
        plan_code: plan.code,
        billing_time: "anniversary"
      }
    end

    before { organization.update!(premium_integrations: ["preview"]) }

    it "creates a preview invoice" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoice]).to include(
        billing_entity_code: organization.default_billing_entity.code,
        invoice_type: "subscription",
        fees_amount_cents: 100,
        taxes_amount_cents: 20,
        total_amount_cents: 120,
        currency: "EUR"
      )
    end

    context "with exact time" do
      let(:timestamp) { Time.zone.parse("15 Mar 2024") }

      it "creates a preview invoice" do
        travel_to(timestamp) do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice]).to include(
            billing_entity_code: organization.default_billing_entity.code,
            invoice_type: "subscription",
            issuing_date: "2024-04-15",
            fees_amount_cents: 100,
            taxes_amount_cents: 20,
            total_amount_cents: 120,
            currency: "EUR"
          )
        end
      end
    end

    context "when plan has fixed charges" do
      let(:fixed_charge) { create(:fixed_charge, plan:, units: 2, charge_model: "standard", properties: {amount: "10"}) }

      before { fixed_charge }

      it "creates a preview invoice with fixed charges" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice]).to include(
          fees_amount_cents: 2100,
          taxes_amount_cents: 420,
          total_amount_cents: 2520,
          currency: "EUR"
        )
        expect(json[:invoice][:fees]).to include(
          hash_including(
            item: hash_including(
              type: "fixed_charge"
            ),
            amount_cents: 2000,
            units: "2.0"
          )
        )
      end
    end

    context "when sending billing_entity_code" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:applied_tax) { create(:billing_entity_applied_tax, billing_entity:, tax:) }
      let(:preview_params) do
        {
          customer: {
            name: "test 1",
            currency: "EUR",
            tax_identification_number: "123456789"
          },
          plan_code: plan.code,
          billing_time: "anniversary",
          billing_entity_code: billing_entity.code
        }
      end

      before { applied_tax }

      it "creates a preview invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice]).to include(
          billing_entity_code: billing_entity.code,
          invoice_type: "subscription",
          fees_amount_cents: 100,
          taxes_amount_cents: 20,
          total_amount_cents: 120,
          currency: "EUR"
        )
      end

      context "when billing entity does not exist" do
        let(:preview_params) do
          {
            customer: {
              name: "test 1",
              currency: "EUR",
              tax_identification_number: "123456789"
            },
            plan_code: plan.code,
            billing_time: "anniversary",
            billing_entity_code: SecureRandom.uuid
          }
        end

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
        end
      end

      context "when previewing a new subscription for an existing customer with multi_entity_billing enabled" do
        let(:existing_customer) { create(:customer, organization:, currency: "EUR") }
        let(:preview_params) do
          {
            customer: {external_id: existing_customer.external_id},
            plan_code: plan.code,
            billing_time: "anniversary",
            billing_entity_code: billing_entity.code
          }
        end

        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "creates a preview invoice under the requested billing entity" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice]).to include(
            billing_entity_code: billing_entity.code,
            invoice_type: "subscription"
          )
        end
      end

      context "when previewing for an anonymous customer with multi_entity_billing enabled" do
        let(:preview_params) do
          {
            customer: {
              name: "test 1",
              currency: "EUR",
              tax_identification_number: "123456789"
            },
            plan_code: plan.code,
            billing_time: "anniversary",
            billing_entity_code: billing_entity.code
          }
        end

        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "stamps the invoice with the requested billing entity" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice]).to include(
            billing_entity_code: billing_entity.code,
            invoice_type: "subscription"
          )
        end
      end
    end

    context "when subscriptions are persisted" do
      let(:customer) { create(:customer, organization:, external_id: "123456789") }
      let(:subscription1) { create(:subscription, customer:, billing_time: "anniversary", subscription_at: Time.current) }
      let(:subscription2) { create(:subscription, customer:, billing_time: "anniversary", subscription_at: Time.current) }
      let(:preview_params) do
        {
          customer: {
            external_id: "123456789"
          },
          subscriptions: {
            external_ids: [subscription1.external_id, subscription2.external_id]
          }
        }
      end

      it "creates a preview invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice]).to include(
          invoice_type: "subscription",
          fees_amount_cents: 200,
          taxes_amount_cents: 40,
          total_amount_cents: 240,
          currency: "EUR"
        )
      end

      context "with exact time" do
        let(:timestamp) { Time.zone.parse("15 Mar 2024") }
        let(:subscription1) do
          create(
            :subscription,
            customer:,
            billing_time: "anniversary",
            subscription_at: timestamp - 1.month - 5.days,
            started_at: timestamp - 1.month - 5.days
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            billing_time: "anniversary",
            subscription_at: timestamp - 1.month - 5.days,
            started_at: timestamp - 1.month - 5.days
          )
        end

        it "creates a preview invoice" do
          travel_to(timestamp) do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:invoice]).to include(
              invoice_type: "subscription",
              issuing_date: "2024-04-10",
              fees_amount_cents: 200,
              taxes_amount_cents: 40,
              total_amount_cents: 240,
              currency: "EUR"
            )
          end
        end
      end

      context "when subscription's plan has fixed charges" do
        let(:fixed_charge) { create(:fixed_charge, plan: subscription1.plan, units: 2, charge_model: "standard", properties: {amount: "10"}) }
        let(:fixed_charge_event) { create(:fixed_charge_event, subscription: subscription1, fixed_charge:, units: 2) }

        before { fixed_charge_event }

        it "creates a preview invoice with fixed charges" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice]).to include(
            fees_amount_cents: 2200,
            taxes_amount_cents: 440,
            total_amount_cents: 2640,
            currency: "EUR"
          )
          expect(json[:invoice][:fees]).to include(
            hash_including(
              item: hash_including(
                type: "fixed_charge"
              ),
              amount_cents: 2000,
              units: "2.0"
            )
          )
        end
      end
    end

    context "when subscriptions are persisted but only one belongs to the customer" do
      let(:customer) { create(:customer, organization:, external_id: "123456789") }
      let(:subscription1) { create(:subscription, billing_time: "anniversary", subscription_at: Time.current) }
      let(:subscription2) { create(:subscription, customer:, billing_time: "anniversary", subscription_at: Time.current) }
      let(:preview_params) do
        {
          customer: {
            external_id: "123456789"
          },
          subscriptions: {
            external_ids: [subscription1.external_id, subscription2.external_id]
          }
        }
      end

      it "creates a preview invoice" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoice]).to include(
          invoice_type: "subscription",
          fees_amount_cents: 100,
          taxes_amount_cents: 20,
          total_amount_cents: 120,
          currency: "EUR"
        )
      end
    end

    context "when subscriptions do not belong to the customer" do
      let(:customer) { create(:customer, organization:, external_id: "123456789") }
      let(:subscription1) { create(:subscription, billing_time: "anniversary", subscription_at: Time.current) }
      let(:subscription2) { create(:subscription, billing_time: "anniversary", subscription_at: Time.current) }
      let(:preview_params) do
        {
          customer: {
            external_id: "123456789"
          },
          subscriptions: {
            external_ids: [subscription1.external_id, subscription2.external_id]
          }
        }
      end

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when customer does not exist" do
      let(:preview_params) do
        {
          customer: {
            external_id: "unknown"
          },
          plan_code: plan.code
        }
      end

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when coupons have invalid type" do
      let(:preview_params) do
        {
          coupons: {
            code: "unknown"
          }
        }
      end

      it "returns a bad request error" do
        subject
        expect(response).to have_http_status(:bad_request)
        expect(json[:error]).to eq "coupons_must_be_an_array"
      end
    end

    context "when subscriptions have invalid type" do
      let(:preview_params) do
        {
          subscriptions: []
        }
      end

      it "returns a bad request error" do
        subject
        expect(response).to have_http_status(:bad_request)
        expect(json[:error]).to eq "subscriptions_must_be_an_object"
      end
    end

    context "with pending subscription starting in the future" do
      let(:timestamp) { Time.zone.parse("15 Mar 2024") }
      let(:future_start) { Time.zone.parse("1 Apr 2024") }
      let(:customer) { create(:customer, organization:, external_id: "pending_customer") }
      let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: false) }
      let(:pending_subscription) do
        create(
          :subscription,
          customer:,
          plan:,
          status: :pending,
          subscription_at: future_start,
          billing_time: "calendar"
        )
      end
      let(:preview_params) do
        {
          customer: {
            external_id: customer.external_id
          },
          subscriptions: {
            external_ids: [pending_subscription.external_id]
          }
        }
      end

      before { pending_subscription }

      it "creates preview invoice for pending subscription with arrears billing" do
        travel_to(timestamp) do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice]).to include(
            invoice_type: "subscription",
            issuing_date: "2024-05-01",
            fees_amount_cents: 100,
            taxes_amount_cents: 20,
            total_amount_cents: 120
          )
        end
      end

      context "with in advance billing" do
        let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }

        it "creates preview invoice for pending subscription" do
          travel_to(timestamp) do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:invoice]).to include(
              invoice_type: "subscription",
              issuing_date: "2024-04-01",
              fees_amount_cents: 100,
              taxes_amount_cents: 20,
              total_amount_cents: 120
            )
          end
        end
      end

      context "with anniversary billing" do
        let(:future_start) { Time.zone.parse("8 Apr 2024") }
        let(:plan) { create(:plan, organization:, interval: "monthly", pay_in_advance: true) }
        let(:pending_subscription) do
          create(
            :subscription,
            customer:,
            plan:,
            status: :pending,
            subscription_at: future_start,
            billing_time: "anniversary"
          )
        end

        it "creates preview invoice for pending subscription" do
          travel_to(timestamp) do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:invoice]).to include(
              invoice_type: "subscription",
              issuing_date: "2024-04-08",
              fees_amount_cents: 100,
              taxes_amount_cents: 20,
              total_amount_cents: 120
            )
          end
        end
      end
    end

    context "with a scheduled downgrade (projection)" do
      let(:customer) { create(:customer, organization:, external_id: "downgrade_customer") }
      let(:current_plan) do
        create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000)
      end
      let(:next_plan) do
        create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 500)
      end
      let(:subscription) do
        create(
          :subscription,
          customer:,
          plan: current_plan,
          status: :active,
          billing_time: "anniversary",
          subscription_at: Time.zone.parse("2026-03-03"),
          started_at: Time.zone.parse("2026-03-03")
        )
      end
      let(:next_subscription) do
        create(
          :subscription,
          :pending,
          customer:,
          plan: next_plan,
          billing_time: "anniversary",
          previous_subscription: subscription,
          subscription_at: Time.zone.parse("2026-07-03")
        )
      end
      let(:preview_params) do
        {
          customer: {external_id: customer.external_id},
          subscriptions: {external_ids: [subscription.external_id]}
        }
      end

      before { next_subscription }

      it "serializes the pending plan's real first billing period" do
        travel_to(Time.zone.parse("2026-06-04T10:00:00Z")) do
          subject

          expect(response).to have_http_status(:success)

          subscriptions = json[:invoice][:subscriptions]
          expect(subscriptions.size).to eq(2)

          pending_plan = subscriptions.find { |s| s[:plan_code] == next_plan.code }
          expect(pending_plan).to be_present
          expect(pending_plan[:started_at]).to eq("2026-07-03T00:00:00.000Z")
          expect(pending_plan[:current_billing_period_started_at]).to eq("2026-07-03T00:00:00Z")
          expect(pending_plan[:current_billing_period_ending_at]).to eq("2026-08-02T23:59:59Z")
          expect(pending_plan[:current_billing_period_started_at])
            .not_to eq(pending_plan[:current_billing_period_ending_at])
        end
      end
    end

    context "with a not-yet-scheduled downgrade (plan_code)" do
      let(:customer) { create(:customer, organization:, external_id: "plan_change_customer") }
      let(:current_plan) do
        create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000)
      end
      let(:target_plan) do
        create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 500)
      end
      let(:subscription) do
        create(
          :subscription,
          customer:,
          plan: current_plan,
          status: :active,
          billing_time: "anniversary",
          subscription_at: Time.zone.parse("2026-03-03"),
          started_at: Time.zone.parse("2026-03-03")
        )
      end
      let(:preview_params) do
        {
          customer: {external_id: customer.external_id},
          subscriptions: {external_ids: [subscription.external_id], plan_code: target_plan.code}
        }
      end

      before { subscription }

      it "serializes the target plan's real first billing period" do
        travel_to(Time.zone.parse("2026-06-04T10:00:00Z")) do
          subject

          expect(response).to have_http_status(:success)

          pending_plan = json[:invoice][:subscriptions].find { |s| s[:plan_code] == target_plan.code }
          expect(pending_plan).to be_present
          expect(pending_plan[:started_at]).to eq("2026-07-03T00:00:00.000Z")
          expect(pending_plan[:current_billing_period_started_at]).to eq("2026-07-03T00:00:00Z")
          expect(pending_plan[:current_billing_period_ending_at]).to eq("2026-08-02T23:59:59Z")
          expect(pending_plan[:current_billing_period_started_at])
            .not_to eq(pending_plan[:current_billing_period_ending_at])
        end
      end
    end

    context "when subscription has a minimum commitment and terminated_at is provided" do
      let(:timestamp) { Time.zone.parse("2026-01-15") }
      let(:commitment_customer) { create(:customer, organization:, external_id: "commitment_customer") }
      let(:commitment_plan) do
        create(:plan, organization:, interval: "yearly", pay_in_advance: false, amount_cents: 100_00)
      end
      let(:subscription) do
        create(
          :subscription,
          customer: commitment_customer,
          plan: commitment_plan,
          billing_time: "calendar",
          started_at: Time.zone.parse("2026-01-01"),
          subscription_at: Time.zone.parse("2026-01-01")
        )
      end
      let(:preview_params) do
        {
          customer: {external_id: commitment_customer.external_id},
          subscriptions: {
            external_ids: [subscription.external_id],
            terminated_at: "2026-07-01T00:00:00Z"
          }
        }
      end

      before do
        create(:commitment, :minimum_commitment, plan: commitment_plan, amount_cents: 1_000_00)
      end

      it "creates a preview invoice with a commitment true-up fee" do
        travel_to(timestamp) do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:invoice][:fees]).to include(
            hash_including(item: hash_including(type: "commitment"))
          )
        end
      end
    end
  end
end
