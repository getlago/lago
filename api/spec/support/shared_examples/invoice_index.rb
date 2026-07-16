# frozen_string_literal: true

RSpec.shared_examples "an invoice index endpoint" do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20) }

  before { tax }

  context "without params" do
    let(:params) { {} }
    let!(:invoice) { create(:invoice, :draft, customer:, organization:) }

    include_examples "requires API permission", "invoice", "read"

    it "returns invoices" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first).to include(
        lago_id: invoice.id,
        payment_status: invoice.payment_status,
        status: invoice.status
      )
    end

    context "when customer has an integration customer" do
      let!(:netsuite_customer) { create(:netsuite_customer, customer:) }

      it "returns an invoice with customer having integration customers" do
        subject

        expect(json[:invoices].first[:customer][:integration_customers].first)
          .to include(lago_id: netsuite_customer.id)
      end
    end
  end

  context "with pagination" do
    let(:params) { {page: 1, per_page: 1} }

    before do
      create(:invoice, :draft, customer:, organization:)
      create(:invoice, customer:, organization:)
    end

    it "returns invoices with correct meta data" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:invoices].count).to eq(1)
      expect(json[:meta]).to include(
        current_page: 1,
        next_page: 2,
        prev_page: nil,
        total_pages: 2,
        total_count: 2
      )
    end
  end

  context "when preloading offset amounts" do
    let(:params) { {} }
    let(:preloadable_invoices) { create_list(:invoice, 2, customer:, organization:) }

    before { preloadable_invoices }

    include_examples "preloads offset amounts"
  end

  context "with issuing_date params" do
    let(:params) do
      {issuing_date_from: 2.days.ago.to_date, issuing_date_to: Date.tomorrow.to_date}
    end

    let!(:matching_invoice) do
      create(:invoice, customer:, issuing_date: 1.day.ago.to_date, organization:)
    end

    before { create(:invoice, customer:, issuing_date: 3.days.ago.to_date, organization:) }

    it "returns invoices with correct issuing date" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end

    context "when issuing date is not a valid date" do
      let(:params) { {issuing_date_from: "2020 01 01", issuing_date_to: "01/01/2030"} }

      it "returns the result without filtering" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(2)
      end
    end
  end

  context "with status params" do
    let(:params) { {status: "finalized"} }
    let!(:matching_invoice) { create(:invoice, customer:, organization:) }

    before { create(:invoice, :draft, customer:, organization:) }

    it "returns invoices for the given status" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end

    context "with statuses params" do
      let(:params) { {statuses: ["finalized", "failed"]} }
      let(:failed_invoice) { create(:invoice, :failed, customer:, organization:) }

      before { failed_invoice }

      it "returns invoices for the given statuses" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(2)
        expect(json[:invoices].map { |i| i[:lago_id] }).to include(matching_invoice.id, failed_invoice.id)
      end
    end
  end

  context "with payment status param" do
    let(:params) { {payment_status: "pending"} }

    let!(:matching_invoice) do
      create(:invoice, customer:, payment_status: :pending, organization:)
    end
    let!(:payment_failed_invoice) do
      create(:invoice, customer:, payment_status: :failed, organization:)
    end

    before do
      create(:invoice, customer:, payment_status: :succeeded, organization:)
    end

    it "returns invoices with correct payment status" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end

    context "with multiple payment statuses params" do
      let(:params) { {payment_statuses: ["pending", "failed"]} }

      it "returns invoices with correct payment status" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(2)
        expect(json[:invoices].map { |i| i[:lago_id] }).to include(matching_invoice.id, payment_failed_invoice.id)
      end
    end
  end

  context "with payment overdue param" do
    let(:params) { {payment_overdue: true} }

    let!(:matching_invoice) do
      create(:invoice, customer:, payment_overdue: true, organization:)
    end

    before { create(:invoice, customer:, organization:) }

    it "returns payment overdue invoices" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end
  end

  context "with invoice type param" do
    let(:params) { {invoice_type: "advance_charges"} }

    let!(:matching_invoice) do
      create(:invoice, customer:, invoice_type: :advance_charges, organization:)
    end

    before { create(:invoice, customer:, invoice_type: :add_on, organization:) }

    it "returns invoices with correct invoice type" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end
  end

  context "with currency param" do
    let(:params) { {currency: "USD"} }

    let!(:matching_invoice) { create(:invoice, customer:, currency: "USD", organization:) }

    before { create(:invoice, customer:, currency: "EUR", organization:) }

    it "returns invoices with correct currency" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end
  end

  context "with payment dispute lost param" do
    let(:params) { {payment_dispute_lost: true} }

    let!(:matching_invoice) { create(:invoice, :dispute_lost, customer:, organization:) }

    before { create(:invoice, customer:, organization:) }

    it "returns invoices with payment dispute lost" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end
  end

  context "with search term param" do
    let(:params) { {search_term: matching_invoice.number} }

    let!(:matching_invoice) do
      create(:invoice, customer:, number: SecureRandom.uuid, organization:)
    end

    before { create(:invoice, customer:, number: "not-relevant-number", organization:) }

    it "returns invoices matching the search terms" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(matching_invoice.id)
    end
  end

  context "with amount filters" do
    let(:params) do
      {
        amount_from: invoices.second.total_amount_cents,
        amount_to: invoices.fourth.total_amount_cents
      }
    end

    let!(:invoices) do
      (1..5).to_a.map do |i|
        create(:invoice, customer:, total_amount_cents: i.succ * 1_000, organization:)
      end # from smallest to biggest
    end

    it "returns invoices with total cents amount in provided range" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].pluck(:lago_id)).to match_array invoices[1..3].pluck(:id)
    end
  end

  context "with metadata filters" do
    let(:params) do
      metadata = matching_invoice.metadata.first

      {
        metadata: {
          metadata.key => metadata.value
        }
      }
    end

    let(:matching_invoice) { create(:invoice, organization:, customer:) }

    before do
      create(:invoice_metadata, invoice: matching_invoice)
      create(:invoice, organization:)
    end

    it "returns invoices with matching metadata filters" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].pluck(:lago_id)).to contain_exactly matching_invoice.id
    end
  end

  context "with self billed filters" do
    let(:params) { {self_billed: true} }

    let(:self_billed_invoice) do
      create(:invoice, :self_billed, customer:, organization:)
    end

    let(:non_self_billed_invoice) do
      create(:invoice, customer:, organization:)
    end

    before do
      self_billed_invoice
      non_self_billed_invoice
    end

    it "returns self billed invoices" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(1)
      expect(json[:invoices].first[:lago_id]).to eq(self_billed_invoice.id)
    end

    context "when self billed is false" do
      let(:params) { {self_billed: false} }

      it "returns non self billed invoices" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(1)
        expect(json[:invoices].first[:lago_id]).to eq(non_self_billed_invoice.id)
      end
    end

    context "when self billed is nil" do
      let(:params) { {self_billed: nil} }

      it "returns all invoices" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(2)
      end
    end
  end

  context "when invoices are created in multiple billing entities" do
    let(:billing_entity2) { create(:billing_entity, organization:) }
    let(:params) { {} }

    let(:invoice1) { create(:invoice, :self_billed, customer:, organization:) }
    let(:invoice2) { create(:invoice, :self_billed, customer:, organization:, billing_entity: billing_entity2) }

    before do
      invoice1
      invoice2
    end

    it "returns all invoices when not filtering by billing entity" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(2)
      expect(json[:invoices].pluck(:lago_id)).to match_array([invoice1.id, invoice2.id])
    end

    context "when filtering by billing entity" do
      let(:params) { {billing_entity_codes: [billing_entity2.code]} }

      it "returns invoices for the specified billing entity" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].count).to eq(1)
        expect(json[:invoices].first[:lago_id]).to eq(invoice2.id)
      end

      context "when one of billing entities does not exist" do
        let(:params) { {billing_entity_codes: [billing_entity2.code, SecureRandom.uuid]} }

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("billing_entity_not_found")
        end
      end
    end
  end

  context "with settlements param" do
    let(:params) { {settlements: settlements} }

    let!(:invoice_with_credit_note_settlement) { create(:invoice, customer:, organization:) }
    let!(:invoice_with_payment_settlement) { create(:invoice, customer:, organization:) }

    let(:credit_note) do
      create(
        :credit_note,
        invoice: invoice_with_credit_note_settlement,
        customer: invoice_with_credit_note_settlement.customer,
        organization:
      )
    end

    before do
      create(
        :invoice_settlement,
        organization:,
        billing_entity: invoice_with_credit_note_settlement.billing_entity,
        target_invoice: invoice_with_credit_note_settlement,
        settlement_type: :credit_note,
        source_credit_note: credit_note
      )

      create(
        :invoice_settlement,
        organization:,
        billing_entity: invoice_with_payment_settlement.billing_entity,
        target_invoice: invoice_with_payment_settlement,
        settlement_type: :payment,
        source_payment: create(:payment)
      )
    end

    context "when settlements is credit_note" do
      let(:settlements) { "credit_note" }

      it "returns invoices with credit note settlements" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].pluck(:lago_id)).to eq([invoice_with_credit_note_settlement.id])
      end
    end

    context "when settlements is payment" do
      let(:settlements) { "payment" }

      it "returns invoices with payment settlements" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:invoices].pluck(:lago_id)).to eq([invoice_with_payment_settlement.id])
      end
    end
  end

  context "with N+1 query detection", bullet: {n_plus_one_query: true, unused_eager_loading: false} do
    let(:params) { {} }
    let(:other_billing_entity) { create(:billing_entity, organization:) }

    before do
      [customer.billing_entity, other_billing_entity].each do |billing_entity|
        invoice = create(:invoice, customer:, organization:, billing_entity:)
        create(:invoice_applied_tax, invoice:, tax:, organization:)
        create(:invoice_metadata, invoice:, organization:)

        invoice.file.attach(
          io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.pdf"))),
          filename: "invoice.pdf",
          content_type: "application/pdf"
        )
        invoice.xml_file.attach(
          io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.xml"))),
          filename: "invoice.xml",
          content_type: "application/xml"
        )
      end
    end

    it "does not trigger N+1 queries on invoice associations" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:invoices].count).to eq(2)
      json[:invoices].each do |invoice|
        expect(invoice[:applied_taxes]).to be_present
        expect(invoice[:metadata]).to be_present
        expect(invoice[:file_url]).to be_present
        expect(invoice[:xml_url]).to be_present
      end
    end
  end
end
