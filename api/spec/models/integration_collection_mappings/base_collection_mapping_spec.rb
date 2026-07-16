# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCollectionMappings::BaseCollectionMapping do
  subject(:mapping) { build(:netsuite_collection_mapping, settings: {}) }

  let(:mapping_types) do
    %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit credit_note account currencies]
  end

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:integration) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:billing_entity).optional }

  it { is_expected.to define_enum_for(:mapping_type).with_values(mapping_types).validating }

  describe "validations" do
    describe "of mapping type uniqueness" do
      let(:mapping_type) { :fallback_item }
      let(:organization) { create(:organization) }
      let(:integration) { create(:netsuite_integration, organization:) }
      let(:other_integration) { create(:netsuite_integration, organization: organization) }
      let(:billing_entity) { create(:billing_entity, organization: organization) }
      let(:other_billing_entity) { create(:billing_entity, organization: organization) }

      context "when billing entity is nil" do
        subject(:mapping) do
          build(:netsuite_collection_mapping, mapping_type:, organization:, integration:)
        end

        context "when it is unique in scope of integration" do
          before do
            create(:netsuite_collection_mapping, mapping_type: :coupon, organization:, integration:)
            create(:netsuite_collection_mapping, organization:, integration: other_integration)
            create(:netsuite_collection_mapping, mapping_type:, organization:, billing_entity: other_billing_entity, integration:)
          end

          it "does not add an error" do
            expect(mapping).to be_valid
          end
        end

        context "when it is not unique in scope of integration and billing entity" do
          before do
            create(:netsuite_collection_mapping, mapping_type:, organization: integration.organization, integration:)
          end

          it "adds an error" do
            expect(mapping).not_to be_valid
            expect(mapping.errors.where(:mapping_type, :taken)).to be_present

            expect { mapping.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /duplicate key value violates unique constraint "index_int_collection_mappings_unique_billing_entity_is_null"/)
          end
        end
      end

      context "when billing entity is not nil" do
        subject(:mapping) do
          build(:netsuite_collection_mapping, mapping_type:, organization:, billing_entity:, integration:)
        end

        context "when it is unique in scope of integration and billing entity" do
          before do
            create(:netsuite_collection_mapping, mapping_type:, organization:, billing_entity: nil, integration:)
            create(:netsuite_collection_mapping, mapping_type:, organization:, billing_entity: other_billing_entity, integration:)
            create(:netsuite_collection_mapping, mapping_type: :coupon, organization:, billing_entity:, integration:)
            create(:netsuite_collection_mapping, mapping_type:, organization:, billing_entity:, integration: other_integration)
          end

          it "does not add an error" do
            expect(mapping).to be_valid
          end
        end

        context "when it is not unique in scope of integration and billing entity" do
          before do
            create(:netsuite_collection_mapping, mapping_type:, organization: integration.organization, billing_entity:, integration:)
          end

          it "adds an error" do
            expect(mapping).not_to be_valid
            expect(mapping.errors.where(:mapping_type, :taken)).to be_present

            expect { mapping.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /duplicate key value violates unique constraint "index_int_collection_mappings_unique_billing_entity_is_not_null"/)
          end
        end
      end
    end

    describe "billing entity organization validation" do
      subject(:mapping) { build(:netsuite_collection_mapping, integration:, billing_entity:) }

      let(:integration) { create(:netsuite_integration) }

      context "when billing entity belongs to the same organization" do
        let(:billing_entity) { create(:billing_entity, organization: integration.organization) }

        it "is valid" do
          expect(mapping).to be_valid
        end
      end

      context "when billing entity belongs to a different organization" do
        let(:billing_entity) { create(:billing_entity) }

        it "is not valid" do
          expect(mapping).not_to be_valid
          expect(mapping.errors[:billing_entity]).to include("value_is_invalid")
        end
      end

      context "when billing entity is nil" do
        let(:billing_entity) { nil }

        it "is valid" do
          expect(mapping).to be_valid
        end
      end
    end
  end

  describe "#push_to_settings" do
    it "push the value into settings" do
      mapping.push_to_settings(key: "key1", value: "val1")

      expect(mapping.settings).to eq(
        {
          "key1" => "val1"
        }
      )
    end
  end

  describe "#get_from_settings" do
    before { mapping.push_to_settings(key: "key1", value: "val1") }

    it { expect(mapping.get_from_settings("key1")).to eq("val1") }

    it { expect(mapping.get_from_settings(nil)).to be_nil }
    it { expect(mapping.get_from_settings("foo")).to be_nil }
  end
end
