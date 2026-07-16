# frozen_string_literal: true

require "rails_helper"

RSpec.describe Taxes::CreateService do
  subject(:create_service) { described_class.new(organization:, params:) }

  let(:organization) { create(:organization) }
  let(:billing_entity) { organization.default_billing_entity }
  let(:code) { "tax_code" }
  let(:params) do
    {
      name: "Tax",
      code:,
      rate: 15.0,
      description: "Tax Description"
    }
  end

  describe "#call" do
    it "creates a tax" do
      expect { create_service.call }.to change(Tax, :count).by(1)
    end

    it "returns tax in the result" do
      result = create_service.call
      expect(result.tax).to be_a(Tax)
    end

    it "does not create an applied tax for the default billing entity" do
      expect { create_service.call }.not_to change { billing_entity.applied_taxes.count }
    end

    context "when applied_to_organization is true" do
      let(:params) do
        {
          name: "Tax",
          code:,
          rate: 15.0,
          description: "Tax Description",
          applied_to_organization: true
        }
      end

      it "creates an applied tax for the default billing entity" do
        expect { create_service.call }.to change { billing_entity.applied_taxes.count }.by(1)
      end

      context "when there are multiple billing entities" do
        let(:billing_entity2) { create(:billing_entity, organization:) }

        before { billing_entity2 }

        it "creates an applied tax for the default billing entity" do
          expect { create_service.call }.to change { billing_entity.applied_taxes.count }.by(1)
          expect { create_service.call }.not_to change { billing_entity2.applied_taxes.count }
        end
      end
    end

    context "with validation error" do
      before { create(:tax, organization:, code:) }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:code]).to eq(["value_already_exist"])
      end
    end
  end
end
