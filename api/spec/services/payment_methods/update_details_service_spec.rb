# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::UpdateDetailsService do
  subject(:create_service) { described_class.new(payment_method:, insert:, delete:) }

  let(:customer) { create(:customer) }
  let(:payment_method) { create(:payment_method, customer:) }
  let(:insert) { {} }
  let(:delete) { {} }

  describe "#call" do
    context "without payment_method" do
      let(:payment_method) { nil }

      it "fails" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("payment_method_not_found")
      end
    end

    context "with insertions" do
      let(:insert) { {test: true, ruby: true} }

      it "insert into details" do
        result = create_service.call
        payment_method = result.payment_method

        expect(payment_method.details).to include(
          "test" => true,
          "ruby" => true
        )
      end

      context "when existing details" do
        let(:payment_method) { create(:payment_method, customer:, details: {existing: "yes"}) }

        it "preserves the existing values" do
          result = create_service.call
          payment_method = result.payment_method

          expect(payment_method.details).to eq(
            {
              "test" => true,
              "ruby" => true,
              "existing" => "yes"
            }
          )
        end

        context "when updating" do
          let(:insert) { {existing: "for sure", ruby: true} }

          it "replaces only the value" do
            result = create_service.call
            payment_method = result.payment_method

            expect(payment_method.details).to eq(
              {
                "ruby" => true,
                "existing" => "for sure"
              }
            )
          end
        end
      end
    end

    context "when deletions" do
      let(:delete) { {keep: false, remove: "me"} }

      context "when the keys does not exist" do
        it "does nothing" do
          older_details = payment_method.details
          result = create_service.call
          payment_method = result.payment_method

          expect(payment_method.details).to eq(older_details)
        end
      end

      context "with existing keys" do
        let(:payment_method) { create(:payment_method, customer:, details: {existing: "yes", keep: false}) }

        it "remove the keys" do
          result = create_service.call
          payment_method = result.payment_method

          expect(payment_method.details).not_to include("keep" => false)
          expect(payment_method.details).to eq({"existing" => "yes"})
        end
      end
    end
  end
end
