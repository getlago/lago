# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotesQuery do
  subject(:result) do
    described_class.call(organization:, search_term:, pagination:, filters:)
  end

  let(:returned_ids) { result.credit_notes.pluck(:id) }

  let(:organization) { customer.organization }
  let(:customer) { create(:customer) }

  let(:pagination) { nil }
  let(:search_term) { nil }
  let(:filters) { {} }

  context "when no filters applied" do
    let!(:credit_notes) { create_pair(:credit_note, customer:) }

    before { create(:credit_note, :draft, customer:) }

    it "returns all finalized credit notes" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to match_array credit_notes.pluck(:id)
    end
  end

  context "when pagination options provided" do
    let(:pagination) { {page: 2, limit: 1} }
    let!(:credit_notes) { create_list(:credit_note, 3, customer:) }

    it "returns paginated credit notes" do
      expect(result).to be_success
      expect(result.credit_notes).to contain_exactly credit_notes.second
      expect(result.credit_notes.current_page).to eq 2
      expect(result.credit_notes.total_pages).to eq 3
      expect(result.credit_notes.total_count).to eq 3
    end
  end

  context "when currency filter applied" do
    let(:filters) { {currency: matching_credit_note.total_amount_currency} }

    let!(:matching_credit_note) { create(:credit_note, total_amount_currency: "EUR", customer:) }

    before { create(:credit_note, total_amount_currency: "USD", customer:) }

    it "returns credit notes with matching total amount currency" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
    end
  end

  context "when customer external id filter applied" do
    let(:filters) { {customer_external_id: customer.external_id} }

    let!(:matching_credit_note) { create(:credit_note, customer:) }

    before do
      another_customer = create(:customer, organization:)
      create(:credit_note, customer: another_customer)
    end

    it "returns credit notes with matching customer external id" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
    end
  end

  context "when customer id filter applied" do
    let(:filters) { {customer_id: customer.id} }

    let!(:matching_credit_note) { create(:credit_note, customer:) }

    before do
      another_customer = create(:customer, organization:)
      create(:credit_note, customer: another_customer)
    end

    it "returns credit notes with matching customer id" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
    end
  end

  context "when reason filter applied" do
    let(:matching_reasons) { CreditNote::REASON.sample(2) }

    let!(:matching_credit_notes) do
      matching_reasons.map { |reason| create(:credit_note, reason:, customer:) }
    end

    let!(:non_matching_credit_note) do
      create(
        :credit_note,
        reason: CreditNote::REASON.excluding(matching_reasons).sample,
        customer:
      )
    end

    context "with valid options" do
      let(:filters) { {reason: matching_reasons} }

      it "returns credit notes with matching reasons" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array matching_credit_notes.pluck(:id)
      end
    end

    context "with invalid options" do
      let(:filters) { {reason: "invalid-reason"} }

      it "returns all credit notes" do
        expect(result).to be_success

        expect(result.credit_notes.pluck(:id))
          .to contain_exactly(*matching_credit_notes.pluck(:id), non_matching_credit_note.id)
      end
    end
  end

  context "when types filter applied" do
    let(:filters) { {types: types} }

    let!(:credit_only) do
      create(:credit_note, customer:, credit_amount_cents: 10, refund_amount_cents: 0, offset_amount_cents: 0)
    end

    let!(:refund_only) do
      create(:credit_note, customer:, credit_amount_cents: 0, refund_amount_cents: 10, offset_amount_cents: 0)
    end

    let!(:offset_only) do
      create(:credit_note, customer:, credit_amount_cents: 0, refund_amount_cents: 0, offset_amount_cents: 10)
    end

    let!(:credit_and_refund) do
      create(:credit_note, customer:, credit_amount_cents: 10, refund_amount_cents: 10, offset_amount_cents: 0)
    end

    let!(:credit_and_offset) do
      create(:credit_note, customer:, credit_amount_cents: 10, refund_amount_cents: 0, offset_amount_cents: 10)
    end

    context "with one type" do
      context "when type is credit" do
        let(:types) { "credit" }

        it "returns credit notes with positive credit amount" do
          expect(result).to be_success
          expect(returned_ids).to match_array([credit_only.id, credit_and_refund.id, credit_and_offset.id])
        end
      end

      context "when type is refund" do
        let(:types) { "refund" }

        it "returns credit notes with positive refund amount" do
          expect(result).to be_success
          expect(returned_ids).to match_array([refund_only.id, credit_and_refund.id])
        end
      end

      context "when type is offset" do
        let(:types) { "offset" }

        it "returns credit notes with positive offset amount" do
          expect(result).to be_success
          expect(returned_ids).to match_array([offset_only.id, credit_and_offset.id])
        end
      end
    end

    context "with multiple types" do
      let(:types) { %w[credit refund] }

      it "returns credit notes matching any of the given types" do
        expect(result).to be_success
        expect(returned_ids).to match_array([credit_only.id, refund_only.id, credit_and_refund.id, credit_and_offset.id])
      end
    end

    context "with invalid type" do
      let(:types) { "invalid-type" }

      it "returns all credit notes" do
        expect(result).to be_success
        expect(returned_ids).to match_array([credit_only.id, refund_only.id, offset_only.id, credit_and_refund.id, credit_and_offset.id])
      end
    end

    context "when there are no matching credit notes" do
      let(:types) { "refund" }

      before do
        CreditNote.where("refund_amount_cents > 0").delete_all
      end

      it "returns no credit notes" do
        expect(result).to be_success
        expect(returned_ids).to be_empty
      end
    end
  end

  context "when credit status filter applied" do
    let(:matching_credit_statuses) { CreditNote::CREDIT_STATUS.sample(2) }

    let!(:matching_credit_notes) do
      matching_credit_statuses.map do |credit_status|
        create(:credit_note, credit_status:, customer:)
      end
    end

    let!(:non_matching_credit_note) do
      create(
        :credit_note,
        credit_status: CreditNote::CREDIT_STATUS.excluding(matching_credit_statuses).sample,
        customer:
      )
    end

    context "with valid options" do
      let(:filters) { {credit_status: matching_credit_statuses} }

      it "returns credit notes with matching credit statuses" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array matching_credit_notes.pluck(:id)
      end
    end

    context "with invalid options" do
      let(:filters) { {credit_status: "invalid-credit-status"} }

      it "returns all credit notes" do
        expect(result).to be_success

        expect(result.credit_notes.pluck(:id))
          .to contain_exactly(*matching_credit_notes.pluck(:id), non_matching_credit_note.id)
      end
    end
  end

  context "when refund status filter applied" do
    let(:matching_refund_statuses) { CreditNote::REFUND_STATUS.sample(2) }

    let!(:matching_credit_notes) do
      matching_refund_statuses.map do |refund_status|
        create(:credit_note, refund_status:, customer:)
      end
    end

    let!(:non_matching_credit_note) do
      create(
        :credit_note,
        refund_status: CreditNote::REFUND_STATUS.excluding(matching_refund_statuses).sample,
        customer:
      )
    end

    context "with valid options" do
      let(:filters) { {refund_status: matching_refund_statuses} }

      it "returns credit notes with matching refund statuses" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array matching_credit_notes.pluck(:id)
      end
    end

    context "with invalid options" do
      let(:filters) { {refund_status: "invalid-refund-status"} }

      it "returns all credit notes" do
        expect(result).to be_success

        expect(result.credit_notes.pluck(:id))
          .to contain_exactly(*matching_credit_notes.pluck(:id), non_matching_credit_note.id)
      end
    end
  end

  context "when invoice number filter applied" do
    let(:filters) { {invoice_number: matching_credit_note.invoice.number} }

    let!(:matching_credit_note) { create(:credit_note, customer:) }

    before do
      invoice = create(:invoice, customer:, number: "FOO-01")
      create(:credit_note, customer:, invoice:)
    end

    it "returns credit notes with matching invoice number" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
    end
  end

  context "when issuing date filters applied" do
    let(:filters) { {issuing_date_from:, issuing_date_to:} }

    let!(:credit_notes) do
      (1..5).to_a.map do |i|
        create(:credit_note, issuing_date: i.days.ago, customer:)
      end.reverse # from oldest to newest
    end

    context "when only issuing date from provided" do
      let(:issuing_date_to) { nil }

      context "with valid date" do
        let(:issuing_date_from) { credit_notes.second.issuing_date }

        it "returns credit notes that were issued after provided date" do
          expect(result).to be_success
          expect(result.credit_notes.pluck(:id)).to match_array credit_notes[1..].pluck(:id)
        end
      end

      context "with invalid date" do
        let(:issuing_date_from) { "invalid_date_value" }

        it "returns a failed result" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:issuing_date_from]).to include("invalid_date")
        end
      end
    end

    context "when only issuing date to provided" do
      let(:issuing_date_from) { nil }

      context "with valid date" do
        let(:issuing_date_to) { credit_notes.fourth.issuing_date }

        it "returns credit notes that were issued before provided date" do
          expect(result).to be_success
          expect(result.credit_notes.pluck(:id)).to match_array credit_notes[..3].pluck(:id)
        end
      end

      context "with invalid date" do
        let(:issuing_date_to) { "invalid_date_value" }

        it "returns a failed result" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:issuing_date_to]).to include("invalid_date")
        end
      end
    end

    context "when both issuing date from and issuing date to provided" do
      let(:issuing_date_from) { credit_notes.second.issuing_date }
      let(:issuing_date_to) { credit_notes.fourth.issuing_date }

      it "returns credit notes that were issued between provided dates" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array credit_notes[1..3].pluck(:id)
      end
    end
  end

  context "when amount filters applied" do
    let(:filters) { {amount_from:, amount_to:} }

    let!(:credit_notes) do
      (1..5).to_a.map do |i|
        create(:credit_note, total_amount_cents: i.succ * 1_000, customer:)
      end # from smallest to biggest
    end

    context "when only amount from provided" do
      let(:amount_from) { credit_notes.second.total_amount_cents }
      let(:amount_to) { nil }

      it "returns credit notes with total cents amount bigger or equal to provided value" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array credit_notes[1..].pluck(:id)
      end
    end

    context "when only amount to provided" do
      let(:amount_from) { nil }
      let(:amount_to) { credit_notes.fourth.total_amount_cents }

      it "returns credit notes with total cents amount lower or equal to provided value" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array credit_notes[..3].pluck(:id)
      end
    end

    context "when both amount from and amount to provided" do
      let(:amount_from) { credit_notes.second.total_amount_cents }
      let(:amount_to) { credit_notes.fourth.total_amount_cents }

      it "returns credit notes with total cents amount in provided range" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to match_array credit_notes[1..3].pluck(:id)
      end
    end
  end

  context "when filtering by self_billed" do
    let(:credit_note_first) do
      invoice = create(:invoice, :self_billed, organization:, customer:)

      create(:credit_note, customer:, invoice:)
    end

    let(:credit_note_second) do
      invoice = create(:invoice, organization:, customer:)

      create(:credit_note, customer:, invoice:)
    end

    before do
      credit_note_first
      credit_note_second
    end

    context "when self_billed is true" do
      let(:filters) { {self_billed: true} }

      it "returns only credit notes from self billed invoices" do
        expect(returned_ids).to include(credit_note_first.id)
        expect(returned_ids).not_to include(credit_note_second.id)
      end
    end

    context "when self_billed is false" do
      let(:filters) { {self_billed: false} }

      it "returns only credit notes from non self billed invoices" do
        expect(returned_ids).not_to include(credit_note_first.id)
        expect(returned_ids).to include(credit_note_second.id)
      end
    end

    context "when self_billed is nil" do
      let(:filters) { {self_billed: nil} }

      it "returns all credit notes" do
        expect(returned_ids).to include(credit_note_first.id)
        expect(returned_ids).to include(credit_note_second.id)
      end
    end
  end

  context "when billing entity ids filter applied" do
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:filters) { {billing_entity_ids: [billing_entity.id]} }

    let(:matching_credit_note) { create(:credit_note, customer:, invoice: create(:invoice, billing_entity:)) }
    let(:other_credit_note) { create(:credit_note, customer:, invoice: create(:invoice, organization:)) }

    before do
      matching_credit_note
      other_credit_note
    end

    it "returns credit notes with matching billing entity id" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
    end

    context "when matching credit notes from more than one billing_entity" do
      let(:billing_entity_2) { create(:billing_entity, organization:) }
      let(:filters) { {billing_entity_ids: [billing_entity.id, billing_entity_2.id]} }

      let(:matching_credit_note_2) { create(:credit_note, customer:, invoice: create(:invoice, billing_entity: billing_entity_2)) }

      before do
        matching_credit_note_2
      end

      it "returns credit notes with matching billing entity ids" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly(matching_credit_note.id, matching_credit_note_2.id)
      end
    end
  end

  context "when search term filter applied" do
    context "with term matching credit note by id" do
      let(:search_term) { matching_credit_note.id.first(10) }
      let!(:matching_credit_note) { create(:credit_note, customer:) }

      before { create(:credit_note, customer:) }

      it "returns credit notes by partially matching id" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end

    context "with term matching credit note by number" do
      let(:search_term) { matching_credit_note.number.first(10) }
      let!(:matching_credit_note) { create(:credit_note, customer:) }

      before do
        invoice = create(:invoice, customer:, number: "FOO-01")
        create(:credit_note, customer:, invoice:)
      end

      it "returns credit notes by partially matching number" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end

    context "with term matching credit note by customer name" do
      let(:search_term) { customer.name.first(6) }

      let(:customer) do
        create(
          :customer,
          name: "Rick Sanchez",
          firstname: "Rick Ramon",
          lastname: "Sanchez Spencer"
        )
      end

      let!(:matching_credit_note) { create(:credit_note, customer:) }

      before do
        another_customer = create(
          :customer,
          organization:,
          name: "Morty Smith",
          firstname: "Morty Elias",
          lastname: "Smith Murray"
        )

        create(
          :credit_note,
          customer: another_customer,
          invoice: create(:invoice, customer: another_customer)
        )
      end

      it "returns credit notes by partially matching customer name" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end

    context "with term matching credit note by customer first name" do
      let(:search_term) { customer.firstname.first(6) }

      let(:customer) do
        create(
          :customer,
          name: "Rick Sanchez",
          firstname: "Rick Ramon",
          lastname: "Sanchez Spencer"
        )
      end

      let!(:matching_credit_note) do
        create(:credit_note, customer:, invoice: create(:invoice, customer:))
      end

      before do
        another_customer = create(
          :customer,
          organization:,
          name: "Morty Smith",
          firstname: "Morty Elias",
          lastname: "Smith Murray"
        )

        create(
          :credit_note,
          customer: another_customer,
          invoice: create(:invoice, customer: another_customer)
        )
      end

      it "returns credit notes by partially matching customer first name", aggregate_failures: false do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end

    context "with term matching credit note by customer last name" do
      let(:search_term) { customer.lastname.first(8) }

      let(:customer) do
        create(
          :customer,
          name: "Rick Sanchez",
          firstname: "Rick Ramon",
          lastname: "Sanchez Spencer"
        )
      end

      let!(:matching_credit_note) do
        create(:credit_note, customer:, invoice: create(:invoice, customer:))
      end

      before do
        another_customer = create(
          :customer,
          organization:,
          name: "Morty Smith",
          firstname: "Morty Elias",
          lastname: "Smith Murray"
        )

        create(
          :credit_note,
          customer: another_customer,
          invoice: create(:invoice, customer: another_customer)
        )
      end

      it "returns credit notes by partially matching customer last name" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end

    context "with term matching credit note by customer external id" do
      let(:search_term) { matching_credit_note.customer.external_id.first(10) }
      let!(:matching_credit_note) { create(:credit_note, customer:) }

      before do
        another_customer = create(:customer, organization:)
        create(:credit_note, customer: another_customer)
      end

      it "returns credit notes by partially matching customer external id" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end

    context "with term matching credit note by customer email" do
      let(:search_term) { matching_credit_note.customer.email.first(5) }
      let!(:matching_credit_note) { create(:credit_note, customer:) }

      before do
        another_customer = create(:customer, organization:)
        create(:credit_note, customer: another_customer)
      end

      it "returns credit notes by partially matching customer email" do
        expect(result).to be_success
        expect(result.credit_notes.pluck(:id)).to contain_exactly matching_credit_note.id
      end
    end
  end

  context "with multiple filters applied at the same time" do
    let(:search_term) { credit_note.number.first(5) }

    let(:filters) do
      {
        currency: credit_note.currency,
        customer_external_id: credit_note.customer.external_id,
        customer_id: credit_note.customer.id,
        reason: credit_note.reason,
        credit_status: credit_note.credit_status,
        refund_status: credit_note.refund_status,
        invoice_number: credit_note.invoice.number,
        issuing_date_from: credit_note.issuing_date,
        issuing_date_to: credit_note.issuing_date,
        amount_from: credit_note.total_amount_cents,
        amount_to: credit_note.total_amount_cents
      }
    end

    let!(:credit_note) { create(:credit_note, total_amount_currency: "EUR", customer:) }

    before { create(:credit_note, total_amount_currency: "USD", customer:) }

    it "returns credit notes matching all provided filters" do
      expect(result).to be_success
      expect(result.credit_notes.pluck(:id)).to contain_exactly credit_note.id
    end
  end
end
