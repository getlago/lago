# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationMappings::BaseMapping do
  subject(:mapping) { build(:netsuite_mapping, settings: {}) }

  it_behaves_like "paper_trail traceable"

  describe "associations" do
    it { is_expected.to belong_to(:integration) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:mappable) }
    it { is_expected.to belong_to(:billing_entity).optional }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:mappable_type).in_array(%w[AddOn BillableMetric]) }

    describe "uniqueness validations" do
      let(:mapping) do
        build(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity:)
      end
      let(:organization) { create(:organization) }
      let(:integration) { create(:netsuite_integration, organization: organization) }
      let(:add_on) { create(:add_on, organization: organization) }
      let(:other_add_on) { create(:add_on, organization: organization) }
      let(:billable_metric) { create(:billable_metric, id: add_on.id, organization: organization) }
      let(:other_integration) { create(:netsuite_integration, organization: organization) }
      let(:billing_entity) { create(:billing_entity, organization: organization) }
      let(:other_billing_entity) { create(:billing_entity, organization: organization) }
      let(:other_organization) { create(:organization) }

      context "without billing entity" do
        let(:mapping) do
          build(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity: nil)
        end

        context "when it is unique in scope of mappable_id, integration_id" do
          before do
            create(:netsuite_mapping, integration: other_integration, organization:, mappable: add_on, billing_entity: nil)
            create(:netsuite_mapping, integration:, organization:, mappable: other_add_on, billing_entity: nil)
            create(:netsuite_mapping, integration:, mappable: add_on, billing_entity: nil, organization: other_organization)
            create(:netsuite_mapping, integration:, organization:, mappable: billable_metric, billing_entity: nil)
            create(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity: other_billing_entity)
          end

          it "does not add an error" do
            expect(mapping).to be_valid
          end
        end

        context "when it is not unique in scope of mappable_id, integration_id, and billing_entity_id" do
          before do
            create(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity: nil)
          end

          it "adds an error" do
            expect(mapping).not_to be_valid
            expect(mapping.errors.where(:mappable_type, :taken)).to be_present

            expect { mapping.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /duplicate key value violates unique constraint "index_integration_mappings_unique_billing_entity_id_is_null"/)
          end
        end
      end

      context "with billing entity" do
        context "when it is unique in scope of mappable_id, integration_id, and billing_entity_id" do
          before do
            create(:netsuite_mapping, integration: other_integration, organization:, mappable: add_on, billing_entity:)
            create(:netsuite_mapping, integration:, organization:, mappable: other_add_on, billing_entity:)
            create(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity: other_billing_entity)
            create(:netsuite_mapping, integration:, organization:, mappable: billable_metric, billing_entity:)
            create(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity: nil)
          end

          it "does not add an error" do
            expect(mapping).to be_valid
          end
        end

        context "when it is not unique in scope of mappable_id, integration_id, and billing_entity_id" do
          before do
            create(:netsuite_mapping, integration:, organization:, mappable: add_on, billing_entity:)
          end

          it "adds an error" do
            expect(mapping).not_to be_valid
            expect(mapping.errors.where(:mappable_type, :taken)).to be_present

            expect { mapping.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /duplicate key value violates unique constraint "index_integration_mappings_unique_billing_entity_id_is_not_null"/)
          end
        end
      end
    end

    describe "billing entity organization validation" do
      let(:organization) { create(:organization) }
      let(:different_organization) { create(:organization) }
      let(:integration) { create(:netsuite_integration, organization: organization) }
      let(:billing_entity) { create(:billing_entity, organization: different_organization) }
      let(:add_on) { create(:add_on, organization: organization) }

      it "validates billing entity belongs to same organization" do
        mapping = build(
          :netsuite_mapping,
          integration: integration,
          organization: organization,
          billing_entity: billing_entity,
          mappable: add_on,
          external_id: "test_id"
        )

        expect(mapping).not_to be_valid
        expect(mapping.errors[:billing_entity]).to include("must belong to the same organization")
      end

      it "is valid when billing entity belongs to same organization" do
        billing_entity.update!(organization: organization)
        mapping = build(
          :netsuite_mapping,
          integration: integration,
          organization: organization,
          billing_entity: billing_entity,
          mappable: add_on,
          external_id: "test_id"
        )

        expect(mapping).to be_valid
      end

      it "is valid when billing entity is nil" do
        mapping = build(
          :netsuite_mapping,
          integration: integration,
          organization: organization,
          billing_entity: nil,
          mappable: add_on,
          external_id: "test_id"
        )

        expect(mapping).to be_valid
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
