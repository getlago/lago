# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCollectionMappings::NetsuiteCollectionMapping do
  subject(:mapping) { build(:netsuite_collection_mapping) }

  describe "#external_id" do
    let(:external_id) { SecureRandom.uuid }

    it "assigns and retrieve a setting" do
      mapping.external_id = external_id
      expect(mapping.external_id).to eq(external_id)
    end
  end

  describe "#external_account_code" do
    let(:external_account_code) { "netsuite-code-1" }

    it "assigns and retrieve a setting" do
      mapping.external_account_code = external_account_code
      expect(mapping.external_account_code).to eq(external_account_code)
    end
  end

  describe "#external_name" do
    let(:external_name) { "Credits and Discounts" }

    it "assigns and retrieve a setting" do
      mapping.external_name = external_name
      expect(mapping.external_name).to eq(external_name)
    end
  end

  describe "#tax_nexus" do
    let(:tax_nexus) { "tax-nexus-1" }

    it "assigns and retrieve a setting" do
      mapping.tax_nexus = tax_nexus
      expect(mapping.tax_nexus).to eq(tax_nexus)
    end
  end

  describe "#tax_type" do
    let(:tax_type) { "tax-type-1" }

    it "assigns and retrieve a setting" do
      mapping.tax_type = tax_type
      expect(mapping.tax_type).to eq(tax_type)
    end
  end

  describe "#tax_code" do
    let(:tax_code) { "tax-code-1" }

    it "assigns and retrieve a setting" do
      mapping.tax_code = tax_code
      expect(mapping.tax_code).to eq(tax_code)
    end
  end

  describe "#currencies" do
    let(:currencies) { {"EUR" => "8"} }

    it "assigns and retrieve a setting" do
      mapping.currencies = currencies
      expect(mapping.currencies).to eq(currencies)
    end

    it do
      mapping.mapping_type = :currencies
      expect(mapping).to be_invalid
    end
  end

  describe "currencies validation" do
    context "when mapping type is currencies" do
      subject(:mapping) { build(:netsuite_collection_mapping, mapping_type: :currencies) }

      context "when currencies is blank" do
        it do
          mapping.currencies = nil
          expect(mapping).to be_invalid
          expect(mapping.errors[:currencies]).to eq ["value_is_mandatory"]

          mapping.currencies = {}
          expect(mapping).to be_invalid
          expect(mapping.errors[:currencies]).to eq ["cannot_be_empty"]
        end
      end

      context "when currencies is invalid" do
        [
          [],
          "invalid",
          :mapping,
          {"USD" => 8},
          {USD: "8"},
          {"invalid" => "8"},
          {"USD" => :test}

        ].each do |currencies|
          it do
            mapping.currencies = currencies
            expect(mapping).to be_invalid
            expect(mapping.errors[:currencies]).to eq ["invalid_format"]
          end
        end
      end
    end

    context "when currencies is expected" do
      subject(:mapping) { build(:netsuite_collection_mapping, mapping_type: :currencies) }

      it { is_expected.to be_invalid }
    end

    context "when currencies shouldn't be set" do
      subject(:mapping) { build(:netsuite_collection_mapping, mapping_type: :fallback_item) }

      it do
        mapping.currencies = {"EUR" => "12"}
        expect(mapping).to be_invalid
        expect(mapping.errors[:currencies]).to eq ["value_must_be_blank"]
      end
    end
  end

  describe "organization_level_only_mapping validation" do
    context "when mapping type is currencies" do
      subject(:mapping) do
        build(:netsuite_collection_mapping,
          integration:,
          mapping_type: :currencies,
          currencies: {"USD" => "1"})
      end

      let(:integration) { create(:netsuite_integration) }
      let(:billing_entity) { create(:billing_entity, organization: integration.organization) }

      context "when billing_entity_id is present" do
        it do
          mapping.billing_entity = billing_entity
          expect(mapping).to be_invalid
          expect(mapping.errors[:billing_entity]).to include "value_must_be_blank"
        end
      end

      context "when billing_entity_id is nil" do
        it do
          mapping.billing_entity_id = nil
          expect(mapping).to be_valid
        end
      end
    end

    context "when mapping type is not currencies" do
      subject(:mapping) { build(:netsuite_collection_mapping, integration:, mapping_type: :fallback_item) }

      let(:integration) { create(:netsuite_integration) }
      let(:billing_entity) { create(:billing_entity, organization: integration.organization) }

      it do
        mapping.billing_entity = billing_entity
        expect(mapping).to be_valid
      end
    end
  end
end
