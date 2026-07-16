# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::CustomersQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filtering by account type" do
    let(:filters) { {account_type: %w[customer partner]} }

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

  context "when filtering by currencies" do
    let(:filters) { {currencies: ["USD"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by countries" do
    let(:filters) { {countries: ["US"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by states" do
    let(:filters) { {states: ["CA"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by zipcodes" do
    let(:filters) { {zipcodes: ["10115"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by has_tax_identification_number" do
    [
      "true",
      "false",
      true,
      false
    ].each do |value|
      let(:filters) { {has_tax_identification_number: value} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end
  end

  context "when filtering by metadata" do
    let(:filters) { {metadata: {"key" => "value"}} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by customer_type" do
    let(:filters) { {customer_type: "company"} }

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filtering by has_customer_type" do
    context "when filtering by true" do
      let(:filters) { {has_customer_type: true} }

      it "is valid" do
        expect(result.success?).to be(true)
      end

      context "when customer_type is provided" do
        let(:filters) { {has_customer_type: true, customer_type: "company"} }

        it "is valid" do
          expect(result.success?).to be(true)
        end
      end
    end

    context "when filtering by false" do
      let(:filters) { {has_customer_type: false} }

      it "is valid" do
        expect(result.success?).to be(true)
      end

      context "when customer_type is provided" do
        let(:filters) { {has_customer_type: false, customer_type: "company"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({customer_type: ["must be nil when has_customer_type is false"]})
        end
      end
    end
  end

  context "when filters are invalid" do
    it_behaves_like "an invalid filter", :account_type, nil, ["must be an array"]
    it_behaves_like "an invalid filter", :account_type, %w[random], {0 => ["must be one of: customer, partner"]}
    it_behaves_like "an invalid filter", :billing_entity_ids, SecureRandom.uuid, ["must be an array"]
    it_behaves_like "an invalid filter", :billing_entity_ids, %w[random], {0 => ["is in invalid format"]}
    it_behaves_like "an invalid filter", :currencies, %w[random], {0 => [/^must be one of: AED,.*ZMW$/]}
    it_behaves_like "an invalid filter", :countries, %w[random], {0 => [/^must be one of: AD, .*XK$/]}
    it_behaves_like "an invalid filter", :states, SecureRandom.uuid, ["must be an array"]
    it_behaves_like "an invalid filter", :zipcodes, SecureRandom.uuid, ["must be an array"]
    it_behaves_like "an invalid filter", :has_tax_identification_number, SecureRandom.uuid, ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_tax_identification_number, "t", ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_tax_identification_number, "f", ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_tax_identification_number, 1, ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_tax_identification_number, 0, ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :metadata, SecureRandom.uuid, ["must be a hash"]
    it_behaves_like "an invalid filter", :metadata, {0 => "integer key"}, ["keys must be string"]
    it_behaves_like "an invalid filter", :metadata, {"key" => ["must be a string"]}, {"key" => ["must be a string"]}
    it_behaves_like "an invalid filter", :customer_type, "random", ["must be one of: company, individual"]
    it_behaves_like "an invalid filter", :has_customer_type, SecureRandom.uuid, ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_customer_type, "t", ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_customer_type, "f", ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_customer_type, 1, ["must be one of: true, false"]
    it_behaves_like "an invalid filter", :has_customer_type, 0, ["must be one of: true, false"]
  end
end
