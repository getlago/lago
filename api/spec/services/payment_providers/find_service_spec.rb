# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::FindService do
  let(:service) { described_class.new(organization_id:, code:, id:) }
  let(:payment_provider) { create(:adyen_provider, organization:) }
  let(:organization) { create(:organization) }
  let(:id) { nil }

  before { payment_provider }

  describe "#call" do
    subject(:result) { service.call }

    context "when organization does not exist" do
      let(:organization_id) { "not_an_id" }

      context "when code is blank" do
        let(:code) { nil }

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("payment_provider_not_found")
          expect(result.error.error_message).to eq("Payment provider not found")
        end
      end

      context "when code is present" do
        context "when provider with given code does not exist" do
          let(:code) { "not_a_code" }

          it "returns an error" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ServiceFailure)
            expect(result.error.code).to eq("payment_provider_not_found")
            expect(result.error.error_message).to eq("Payment provider not found")
          end
        end

        context "when provider with given code exists" do
          let(:code) { payment_provider.code }

          it "returns an error" do
            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ServiceFailure)
            expect(result.error.code).to eq("payment_provider_not_found")
            expect(result.error.error_message).to eq("Payment provider not found")
          end
        end
      end
    end

    context "when organization exists" do
      let(:organization_id) { organization.id }

      context "when code is blank" do
        let(:code) { nil }

        context "when id is blank" do
          context "when organization has only one provider" do
            it "returns a successful result" do
              expect(result).to be_success
              expect(result.payment_provider).to eq(payment_provider)
            end
          end

          context "when organization has more than one provider" do
            before { create(:adyen_provider, organization:) }

            it "returns an error" do
              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::ServiceFailure)
              expect(result.error.code).to eq("payment_provider_code_missing")
              expect(result.error.error_message).to eq("Payment provider code is missing")
            end
          end
        end

        context "when id is present" do
          let(:id) { payment_provider.id }

          context "when organization has only one provider" do
            it "returns a successful result" do
              expect(result).to be_success
              expect(result.payment_provider).to eq(payment_provider)
            end
          end

          context "when organization has more than one provider" do
            before { create(:adyen_provider, organization:) }

            it "returns a successful result" do
              expect(result).to be_success
              expect(result.payment_provider).to eq(payment_provider)
            end
          end
        end
      end

      context "when code is present" do
        context "when id is blank" do
          context "when provider with given code does not exist" do
            let(:code) { "not_a_code" }

            it "returns an error" do
              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::ServiceFailure)
              expect(result.error.code).to eq("payment_provider_not_found")
              expect(result.error.error_message).to eq("Payment provider not found")
            end
          end

          context "when provider with given code exists" do
            let(:code) { payment_provider.code }

            it "returns a successful result" do
              expect(result).to be_success
              expect(result.payment_provider).to eq(payment_provider)
            end
          end
        end

        context "when id is present" do
          let(:id) { payment_provider.id }

          context "when provider with given code does not exist" do
            let(:code) { "not_a_code" }

            it "returns a successful result" do
              expect(result).to be_success
              expect(result.payment_provider).to eq(payment_provider)
            end
          end

          context "when provider with given code exists" do
            let(:code) { another_payment_provider.code }
            let(:another_payment_provider) { create(:adyen_provider, organization:) }

            it "returns a successful result containing payment provider by id" do
              expect(result).to be_success
              expect(result.payment_provider).to eq(payment_provider)
            end
          end
        end
      end
    end
  end
end
