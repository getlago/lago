# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::InvoicesQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filtering by settlements" do
    let(:filters) { {settlements: "credit_note"} }

    it "is valid" do
      expect(result.success?).to be(true)
    end

    context "when settlement is payment" do
      let(:filters) { {settlements: "payment"} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when filter is an array" do
      let(:filters) { {settlements: ["credit_note"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end

      context "when settlement is payment" do
        let(:filters) { {settlements: ["payment"]} }

        it "is valid" do
          expect(result.success?).to be(true)
        end
      end
    end
  end

  context "when filtering by payment status" do
    let(:filters) { {payment_status: "succeeded"} }

    it "is valid" do
      expect(result.success?).to be(true)
    end

    context "when filter is an array" do
      let(:filters) { {payment_status: ["succeeded", "failed"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end
  end

  context "when filtering by status" do
    let(:filters) { {status: "draft"} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by billing entity ids" do
    let(:filters) { {billing_entity_ids: ["123e4567-e89b-12d3-a456-426614174000"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by self billed" do
    let(:filters) { {self_billed: false} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by partially paid" do
    let(:filters) { {partially_paid: false} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering payment overdue" do
    let(:filters) { {payment_overdue: false} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filters are invalid" do
    it_behaves_like "an invalid filter", :settlements, "random", ["must be one of: payment, credit_note or must be an array"]
    it_behaves_like "an invalid filter", :settlements, ["credit_note", "random"], {1 => ["must be one of: payment, credit_note"]}
    it_behaves_like "an invalid filter", :payment_status, "random", ["must be one of: pending, succeeded, failed or must be an array"]
    it_behaves_like "an invalid filter", :payment_status, ["succeeded", "random"], {1 => ["must be one of: pending, succeeded, failed"]}
    it_behaves_like "an invalid filter", :status, "random", ["must be one of: draft, finalized, voided, failed, pending or must be an array"]
    it_behaves_like "an invalid filter", :status, ["draft", "random"], {1 => ["must be one of: draft, finalized, voided, failed, pending"]}
    it_behaves_like "an invalid filter", :self_billed, "invalid", ["must be boolean"]
    it_behaves_like "an invalid filter", :partially_paid, "invalid", ["must be boolean"]
    it_behaves_like "an invalid filter", :payment_overdue, "invalid", ["must be boolean"]
    it_behaves_like "an invalid filter", :billing_entity_ids, SecureRandom.uuid, ["must be an array"]
    it_behaves_like "an invalid filter", :billing_entity_ids, %w[random], {0 => ["is in invalid format"]}
  end
end
