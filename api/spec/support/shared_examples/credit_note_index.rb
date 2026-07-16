# frozen_string_literal: true

RSpec.shared_examples "a credit note index endpoint" do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:params) { {} }

  context "with no params" do
    let(:invoices) { create_pair(:invoice, organization:, customer:) }

    let!(:credit_notes) do
      invoices.map { |invoice| create(:credit_note, invoice:, customer:) }
    end

    include_examples "requires API permission", "credit_note", "read"

    it "returns a list of credit notes" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].first[:items]).to be_empty
      expect(json[:credit_notes].pluck(:lago_id)).to match_array credit_notes.pluck(:id)
    end
  end

  context "with pagination" do
    let(:params) { {page: 1, per_page: 1} }
    let(:invoices) { create_pair(:invoice, organization:, customer:) }

    before do
      invoices.map { |invoice| create(:credit_note, invoice:, customer:) }
    end

    it "returns the metadata" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].count).to eq(1)

      expect(json[:meta]).to include(
        current_page: 1,
        next_page: 2,
        prev_page: nil,
        total_pages: 2,
        total_count: 2
      )
    end
  end

  context "with reason filter" do
    let(:params) { {reason: matching_reasons} }
    let(:matching_reasons) { CreditNote::REASON.sample(2) }

    let!(:matching_credit_notes) do
      matching_reasons.map { |reason| create(:credit_note, reason:, customer:) }
    end

    before do
      create(
        :credit_note,
        reason: CreditNote::REASON.excluding(matching_reasons).sample,
        customer:
      )
    end

    it "returns credit notes with matching reasons" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to match_array matching_credit_notes.pluck(:id)
    end
  end

  context "with credit status filter" do
    let(:params) { {credit_status: matching_credit_statuses} }
    let(:matching_credit_statuses) { CreditNote::CREDIT_STATUS.sample(2) }

    let!(:matching_credit_notes) do
      matching_credit_statuses.map do |credit_status|
        create(:credit_note, credit_status:, customer:)
      end
    end

    before do
      create(
        :credit_note,
        credit_status: CreditNote::CREDIT_STATUS.excluding(matching_credit_statuses).sample,
        customer:
      )
    end

    it "returns credit notes with matching credit statuses" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to match_array matching_credit_notes.pluck(:id)
    end
  end

  context "with refund status filter" do
    let(:params) { {refund_status: matching_refund_statuses} }
    let(:matching_refund_statuses) { CreditNote::REFUND_STATUS.sample(2) }

    let!(:matching_credit_notes) do
      matching_refund_statuses.map do |refund_status|
        create(:credit_note, refund_status:, customer:)
      end
    end

    before do
      create(
        :credit_note,
        refund_status: CreditNote::REFUND_STATUS.excluding(matching_refund_statuses).sample,
        customer:
      )
    end

    it "returns credit notes with matching refund statuses" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to match_array matching_credit_notes.pluck(:id)
    end
  end

  context "with types filter" do
    let(:params) { {types: types} }

    let(:credit_only) do
      create(:credit_note, customer:, credit_amount_cents: 10, refund_amount_cents: 0, offset_amount_cents: 0)
    end

    let(:refund_only) do
      create(:credit_note, customer:, credit_amount_cents: 0, refund_amount_cents: 10, offset_amount_cents: 0)
    end

    let(:offset_only) do
      create(:credit_note, customer:, credit_amount_cents: 0, refund_amount_cents: 0, offset_amount_cents: 10)
    end

    let(:credit_and_refund) do
      create(:credit_note, customer:, credit_amount_cents: 10, refund_amount_cents: 10, offset_amount_cents: 0)
    end

    let(:credit_and_offset) do
      create(:credit_note, customer:, credit_amount_cents: 10, refund_amount_cents: 0, offset_amount_cents: 10)
    end

    before do
      credit_only
      refund_only
      offset_only
      credit_and_refund
      credit_and_offset
    end

    context "when type is credit" do
      let(:types) { "credit" }

      it "returns credit notes with positive credit amount" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_notes].pluck(:lago_id)).to match_array([credit_only.id, credit_and_refund.id, credit_and_offset.id])
      end
    end

    context "when type is refund" do
      let(:types) { "refund" }

      it "returns credit notes with positive refund amount" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_notes].pluck(:lago_id)).to match_array([refund_only.id, credit_and_refund.id])
      end
    end

    context "when type is offset" do
      let(:types) { "offset" }

      it "returns credit notes with positive offset amount" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_notes].pluck(:lago_id)).to match_array([offset_only.id, credit_and_offset.id])
      end
    end

    context "when multiple types are provided" do
      let(:types) { %w[credit refund] }

      it "returns credit notes matching any of the given types" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_notes].pluck(:lago_id)).to match_array([credit_only.id, refund_only.id, credit_and_refund.id, credit_and_offset.id])
      end
    end
  end

  context "with invoice number filter" do
    let(:params) { {invoice_number: matching_credit_note.invoice.number} }
    let!(:matching_credit_note) { create(:credit_note, customer:) }

    before do
      invoice = create(:invoice, customer:, number: "FOO-01")
      create(:credit_note, customer:, invoice:)
    end

    it "returns credit notes with matching invoice number" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to contain_exactly matching_credit_note.id
    end
  end

  context "with issuing date filters" do
    let(:params) do
      {
        issuing_date_from: credit_notes.second.issuing_date,
        issuing_date_to: credit_notes.fourth.issuing_date
      }
    end

    let!(:credit_notes) do
      (1..5).to_a.map do |i|
        create(:credit_note, issuing_date: i.days.ago, customer:)
      end.reverse # from oldest to newest
    end

    it "returns credit notes that were issued between provided dates" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to match_array credit_notes[1..3].pluck(:id)
    end
  end

  context "with amount filters" do
    let(:params) do
      {
        amount_from: credit_notes.second.total_amount_cents,
        amount_to: credit_notes.fourth.total_amount_cents
      }
    end

    let!(:credit_notes) do
      (1..5).to_a.map do |i|
        create(:credit_note, total_amount_cents: i.succ * 1_000, customer:)
      end # from smallest to biggest
    end

    it "returns credit notes with total cents amount in provided range" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to match_array credit_notes[1..3].pluck(:id)
    end
  end

  context "with self billed invoice filter" do
    let(:params) { {self_billed: true} }

    let(:self_billed_credit_note) do
      invoice = create(:invoice, :self_billed, customer:, organization:)

      create(:credit_note, invoice:, customer:)
    end

    let(:non_self_billed_credit_note) do
      create(:credit_note, customer:)
    end

    before do
      self_billed_credit_note
      non_self_billed_credit_note
    end

    it "returns self billed credit_notes" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].count).to eq(1)
      expect(json[:credit_notes].first[:lago_id]).to eq(self_billed_credit_note.id)
    end

    context "when self billed is false" do
      let(:params) { {self_billed: false} }

      it "returns non self billed credit_notes" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_notes].count).to eq(1)
        expect(json[:credit_notes].first[:lago_id]).to eq(non_self_billed_credit_note.id)
      end
    end

    context "when self billed is nil" do
      let(:params) { {self_billed: nil} }

      it "returns all credit_notes" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_notes].count).to eq(2)
      end
    end
  end

  context "with search term" do
    let(:params) { {search_term: matching_credit_note.invoice.number} }
    let!(:matching_credit_note) { create(:credit_note, customer:) }

    before do
      invoice = create(:invoice, customer:, number: "FOO-01")
      create(:credit_note, customer:, invoice:)
    end

    it "returns credit notes matching the search terms" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to contain_exactly matching_credit_note.id
    end
  end

  context "with billing entity codes filter" do
    let(:params) { {billing_entity_codes: [billing_entity.code]} }
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:matching_credit_note) { create(:credit_note, customer:, invoice: create(:invoice, billing_entity:)) }
    let(:other_credit_note) { create(:credit_note, customer:) }

    before do
      matching_credit_note
      other_credit_note
    end

    it "returns credit notes with matching billing entity code" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].pluck(:lago_id)).to contain_exactly matching_credit_note.id
    end

    context "when one of billing entity codes is not found" do
      let(:params) { {billing_entity_codes: [billing_entity.code, SecureRandom.uuid]} }

      it "returns an error" do
        subject

        expect(response).to have_http_status(:not_found)
        expect(json[:code]).to eq("billing_entity_not_found")
      end
    end
  end

  context "with integration_customers in response" do
    let(:customer) { create(:customer, :with_tax_integration, organization:) }

    before do
      create(:credit_note, customer:)
    end

    it "includes integration_customers in the customer payload" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].first[:customer][:integration_customers].count).to eq(1)
      expect(json[:credit_notes].first[:customer][:integration_customers].first[:lago_id]).to eq(customer.anrok_customer.id)
    end
  end

  context "with credit notes containing all associations", :bullet do
    before do
      # NOTE: Bullet cannot track ActiveStorage's internal blob access through the attachment proxy
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "ActiveStorage::Attachment", association: :blob)
      # NOTE: The charge include is needed for charge-type fees but true-up fees have no charge
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Fee", association: :charge)
      # NOTE: billable_metric is only accessed for charge-type fees; subscription fees never touch it
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Fee", association: :billable_metric)

      # NOTE: Adding the customer payment associations to Bullet safelist, Bullet is right regarding the associations
      # not being used in the CreditNoteSerializer, but we need to eager load them in order to prevent
      # N+1 queries in the CustomerSerializer when serializing the credit note customer
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :stripe_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :gocardless_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :cashfree_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :adyen_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :moneyhash_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :integration_customers)

      invoices = create_list(:invoice, 3, organization:, customer:)
      invoices.each do |invoice|
        subscription = create(:subscription, customer:, organization:)
        charge = create(:standard_charge, plan: subscription.plan)
        charge_filter = create(:charge_filter, charge:)
        fee = create(:fee, invoice:, subscription:, charge:, charge_filter:, organization:)
        create(:fee, true_up_parent_fee: fee, invoice:, subscription:, organization:)
        create(:pricing_unit_usage, fee:, organization:)

        credit_note = create(:credit_note, :with_file, invoice:, customer:)
        create(:credit_note_item, credit_note:, fee:, organization:)
        create(:credit_note_applied_tax, credit_note:, organization:)
        create(:error_detail, owner: credit_note, organization:)
        create(:item_metadata, owner: credit_note, organization:, value: {"foo" => "bar"})
      end
    end

    it "does not trigger N+1 queries" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].count).to eq(3)
      json[:credit_notes].each do |credit_note|
        expect(credit_note[:items]).not_to be_empty
        expect(credit_note[:applied_taxes]).not_to be_empty
        expect(credit_note[:error_details]).not_to be_empty
        expect(credit_note[:metadata]).to eq(foo: "bar")
      end
    end
  end

  context "with metadata" do
    let(:params) { {} }

    before do
      # NOTE: Adding the customer payment associations to Bullet safelist, Bullet is right regarding the associations
      # not being used in the CreditNoteSerializer, but we need to eager load them in order to prevent
      # N+1 queries in the CustomerSerializer when serializing the credit note customer
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :stripe_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :gocardless_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :cashfree_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :adyen_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :moneyhash_customer)
      Bullet.add_safelist(type: :unused_eager_loading, class_name: "Customer", association: :integration_customers)

      invoices = create_list(:invoice, 3, organization:, customer:)
      invoices.each do |invoice|
        credit_note = create(:credit_note, invoice:, customer:)
        create(:item_metadata, owner: credit_note, organization:, value: {"foo" => "bar"})
      end
    end

    it "returns metadata for each credit note", :bullet do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_notes].count).to eq(3)
      json[:credit_notes].each do |credit_note|
        expect(credit_note[:metadata]).to eq(foo: "bar")
      end
    end
  end
end
