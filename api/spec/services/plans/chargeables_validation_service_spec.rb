# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::ChargeablesValidationService do
  subject(:validation_service) { described_class.call(organization:, charges:, fixed_charges:) }

  let(:organization) { create(:organization) }
  let(:charges) { nil }
  let(:fixed_charges) { nil }

  describe "validations" do
    context "when no charges or fixed_charges are provided" do
      it "returns success" do
        expect(validation_service).to be_success
      end
    end

    context "when validating billable metrics" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:charges) do
        [
          {billable_metric_id: billable_metric.id}
        ]
      end

      it "returns success when billable metric exists" do
        expect(validation_service).to be_success
      end

      context "when billable metric does not exist" do
        let(:charges) do
          [
            {billable_metric_id: "non-existent-id"}
          ]
        end

        it "returns not found failure" do
          expect(validation_service).to be_a_failure
          expect(validation_service.error).to be_a(BaseService::NotFoundFailure)
          expect(validation_service.error.message).to eq("billable_metrics_not_found")
        end
      end

      context "when some billable metrics do not exist" do
        let(:billable_metric2) { create(:billable_metric, organization:) }
        let(:charges) do
          [
            {billable_metric_id: billable_metric.id},
            {billable_metric_id: "non-existent-id"}
          ]
        end

        it "returns not found failure" do
          expect(validation_service).to be_a_failure
          expect(validation_service.error).to be_a(BaseService::NotFoundFailure)
          expect(validation_service.error.message).to eq("billable_metrics_not_found")
        end
      end
    end

    context "when validating add ons by id" do
      let(:add_on) { create(:add_on, organization:) }
      let(:fixed_charges) do
        [
          {add_on_id: add_on.id}
        ]
      end

      it "returns success when add on exists" do
        expect(validation_service).to be_success
      end

      context "when add on id does not exist" do
        let(:fixed_charges) do
          [
            {add_on_id: "non-existent-id"}
          ]
        end

        it "returns not found failure" do
          expect(validation_service).to be_a_failure
          expect(validation_service.error).to be_a(BaseService::NotFoundFailure)
          expect(validation_service.error.message).to eq("add_ons_not_found")
        end
      end

      context "when validating add ons by code" do
        let(:fixed_charges) do
          [
            {add_on_code: add_on.code}
          ]
        end

        it "returns success when add on exists" do
          expect(validation_service).to be_success
        end

        context "when add on does not exist" do
          let(:fixed_charges) do
            [
              {add_on_code: "non-existent-code"}
            ]
          end

          it "returns not found failure" do
            expect(validation_service).to be_a_failure
            expect(validation_service.error).to be_a(BaseService::NotFoundFailure)
            expect(validation_service.error.message).to eq("add_ons_not_found")
          end
        end
      end

      context "when validating both add_on_id and add_on_code" do
        let(:add_on2) { create(:add_on, organization:) }
        let(:fixed_charges) do
          [
            {add_on_id: add_on.id},
            {add_on_code: add_on2.code}
          ]
        end

        it "returns success when both exist" do
          expect(validation_service).to be_success
        end
      end

      context "when add_on_id is nil" do
        let(:fixed_charges) do
          [
            {add_on_id: nil, add_on_code: add_on.code}
          ]
        end

        it "ignores nil add_on_id and validates by code" do
          expect(validation_service).to be_success
        end
      end

      context "when add_on_code is nil" do
        let(:fixed_charges) do
          [
            {add_on_id: add_on.id, add_on_code: nil}
          ]
        end

        it "ignores nil add_on_code and validates by id" do
          expect(validation_service).to be_success
        end
      end
    end

    context "when validating both charges and fixed_charges" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:add_on) { create(:add_on, organization:) }
      let(:charges) do
        [
          {billable_metric_id: billable_metric.id}
        ]
      end
      let(:fixed_charges) do
        [
          {add_on_id: add_on.id}
        ]
      end

      it "returns success when both exist" do
        expect(validation_service).to be_success
      end

      context "when billable metric does not exist" do
        let(:charges) do
          [
            {billable_metric_id: "non-existent-id"}
          ]
        end

        it "returns not found failure for billable metrics" do
          expect(validation_service).to be_a_failure
          expect(validation_service.error).to be_a(BaseService::NotFoundFailure)
          expect(validation_service.error.message).to eq("billable_metrics_not_found")
        end
      end

      context "when add-on does not exist" do
        let(:fixed_charges) do
          [
            {add_on_id: "non-existent-id"}
          ]
        end

        it "returns not found failure for fixed charges" do
          expect(validation_service).to be_a_failure
          expect(validation_service.error).to be_a(BaseService::NotFoundFailure)
          expect(validation_service.error.message).to eq("add_ons_not_found")
        end
      end
    end
  end
end
