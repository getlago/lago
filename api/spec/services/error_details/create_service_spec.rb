# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorDetails::CreateService do
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:owner) { create(:invoice, organization:, customer:) }

  describe "#call" do
    subject(:service_call) { described_class.call(params:, owner:, organization:) }

    let(:params) do
      {
        error_code: "tax_error",
        details: {"tax_error" => "taxDateTooFarInFuture"}
      }
    end

    context "when created successfully" do
      context "when all - owner and organization are provided" do
        it "creates an error_detail" do
          expect { service_call }.to change(ErrorDetail, :count).by(1)
        end

        it "returns created error_detail" do
          result = service_call

          expect(result).to be_success
          expect(result.error_details.owner_id).to eq(owner.id)
          expect(result.error_details.owner_type).to eq(owner.class.to_s)
          expect(result.error_details.organization_id).to eq(organization.id)
          expect(result.error_details.details).to eq(params[:details])
        end
      end
    end

    context "when not created successfully" do
      context "when no owner is provided" do
        subject(:service_call) { described_class.call(params:, organization:, owner: nil) }

        it "does not create an error_detail" do
          expect { service_call }.not_to change(ErrorDetail, :count)
        end

        it "returns error for error_detail" do
          result = service_call
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to include("owner_not_found")
        end
      end

      context "when error code is not registered in enum" do
        subject(:service_call) { described_class.call(params:, owner:, organization:) }

        let(:params) do
          {
            error_code: "this_error_code_will_never_achieve_its_goal",
            details: {"this_error_code_will_never_achieve_its_goal" => "does not matter what we send here"}
          }
        end

        it "does not create an error_detail" do
          expect { service_call }.not_to change(ErrorDetail, :count)
        end

        it "returns error for error_detail" do
          result = service_call
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.message).to eq('Validation errors: {"error_code":["value_is_invalid"]}')
        end
      end
    end
  end
end
