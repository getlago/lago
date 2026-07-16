# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::QuotesQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filtering by customer" do
    let(:filters) { {customers: ["00000000-0000-0000-0000-000000000000"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end

    context "when customer filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {customers: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({customers: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {customers: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({customers: {0 => ["is in invalid format"]}})
        end
      end
    end
  end

  context "when filtering by status" do
    context "when filter is valid" do
      let(:filters) { {statuses: ["draft"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when status filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {statuses: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({statuses: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {statuses: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({statuses: {0 => ["must be one of: draft, approved, voided"]}})
        end
      end
    end
  end

  context "when filtering by number" do
    context "when filter is valid" do
      let(:filters) { {numbers: ["QT-2025-0001"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when number filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {numbers: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({numbers: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {numbers: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({numbers: {0 => ["is in invalid format"]}})
        end
      end
    end
  end

  context "when filtering by from_date and to_date" do
    context "when filters are valid" do
      let(:filters) { {from_date: 2.days.ago.iso8601, to_date: Date.current.iso8601} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when from_date is invalid" do
      let(:filters) { {from_date: "invalid date"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include({from_date: ["must be a date"]})
      end
    end

    context "when to_date is invalid" do
      let(:filters) { {to_date: "invalid date"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include({to_date: ["must be a date"]})
      end
    end
  end

  context "when filtering by owners" do
    context "when filter is valid" do
      let(:filters) { {owners: ["00000000-0000-0000-0000-000000000000"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when owners filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {owners: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({owners: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {owners: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({owners: {0 => ["is in invalid format"]}})
        end
      end
    end
  end

  context "when filtering by order_types" do
    context "when filter is valid" do
      let(:filters) { {order_types: ["one_off"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when order_types filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {order_types: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({order_types: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {order_types: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({order_types: {0 => ["must be one of: subscription_creation, subscription_amendment, one_off"]}})
        end
      end
    end
  end
end
