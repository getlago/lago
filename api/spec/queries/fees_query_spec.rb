# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeesQuery do
  subject(:fees_query) { described_class.new(organization:, pagination:, filters:) }

  let(:organization) { create(:organization) }
  let(:pagination) { nil }
  let(:filters) { {} }

  describe "call" do
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:fee) { create(:fee, subscription:, invoice: nil) }

    before { fee }

    it "returns a list of fees" do
      result = fees_query.call

      expect(result).to be_success
      expect(result.fees.count).to eq(1)
      expect(result.fees).to eq([fee])
    end

    context "with multiple fees" do
      let(:fee2) { create(:fee, subscription:, invoice: nil, created_at: fee.created_at) }

      before do
        fee2
        fee2.update! id: "00000000-0000-0000-0000-000000000000"
      end

      it "returns a consistent list when 2 fees have the same created_at" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(2)
        expect(result.fees).to eq([fee2, fee])
      end
    end

    context "with pagination" do
      let(:pagination) { {page: 2, limit: 10} }

      it "applies the pagination" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(0)
        expect(result.fees.current_page).to eq(2)
      end
    end

    context "with subscription filter" do
      let(:filters) { {external_subscription_id: subscription.external_id} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end
    end

    context "with customer filter" do
      let(:filters) { {external_customer_id: customer.external_id} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when fee is for an add_on" do
        let(:add_on) { create(:add_on, organization:) }
        let(:applied_add_on) { create(:applied_add_on, customer:, add_on:) }
        let(:invoice) { create(:invoice, organization:, customer:) }
        let(:fee) { create(:add_on_fee, applied_add_on:, invoice:) }

        let(:filters) { {external_customer_id: customer.external_id} }

        it "applies the filter" do
          result = fees_query.call

          expect(result).to be_success
          expect(result.fees.count).to eq(1)
        end
      end
    end

    context "with currency filter" do
      let(:filters) { {currency: fee.amount_currency} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end
    end

    context "with billable metric code filter" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:plan) { create(:plan, organization:) }
      let(:charge) { create(:standard_charge, billable_metric:, plan:) }

      let(:fee) { create(:charge_fee, charge:, subscription:, invoice: nil) }

      let(:filters) { {billable_metric_code: billable_metric.code} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end
    end

    context "with fee_type filter" do
      let(:filters) { {fee_type: fee.fee_type} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when fee_type is invalid" do
        let(:filters) { {fee_type: "foo_bar"} }

        it "returns a failed result" do
          result = fees_query.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:fee_type]).to include("value_is_invalid")
        end
      end
    end

    context "with payment_status filter" do
      let(:filters) { {payment_status: fee.payment_status} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when payment_status is invalid" do
        let(:filters) { {payment_status: "foo_bar"} }

        it "returns a failed result" do
          result = fees_query.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:payment_status]).to include("value_is_invalid")
        end
      end
    end

    context "with event_transaction_id filter" do
      let(:fee) do
        create(:fee, subscription:, invoice: nil, pay_in_advance_event_transaction_id: "transaction-id")
      end

      let(:filters) { {event_transaction_id: "transaction-id"} }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when regenerated fees exist" do
        let!(:regenerated_fee) do
          create(:fee, subscription:, organization:, pay_in_advance_event_transaction_id: "transaction-id")
        end

        it "includes both the original and the regenerated fee" do
          result = fees_query.call

          expect(result).to be_success
          expect(result.fees.count).to eq(2)
          expect(result.fees).to include(fee, regenerated_fee)
        end

        context "when multiple void/regenerate cycles occur" do
          let!(:second_regenerated_fee) do
            create(:fee, subscription:, organization:, pay_in_advance_event_transaction_id: "transaction-id")
          end

          it "includes all fees in the chain" do
            result = fees_query.call

            expect(result).to be_success
            expect(result.fees.count).to eq(3)
            expect(result.fees).to match_array([fee, regenerated_fee, second_regenerated_fee])
          end
        end
      end
    end

    context "with created_at filters" do
      let(:filters) do
        {
          created_at_from: (fee.created_at - 1.minute).iso8601,
          created_at_to: (fee.created_at + 1.minute).iso8601
        }
      end

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when fee is not covered by range" do
        let(:filters) do
          {
            created_at_from: (fee.created_at - 2.minutes).iso8601,
            created_at_to: (fee.created_at - 2.minutes).iso8601
          }
        end

        it "applies the filter" do
          result = fees_query.call

          expect(result).to be_success
          expect(result.fees.count).to eq(0)
        end
      end

      context "with invalid date" do
        let(:filters) { {created_at_from: "invalid_date_value"} }

        it "returns a failed result" do
          result = fees_query.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:created_at_from]).to include("invalid_date")
        end
      end
    end

    context "with succeeded_at filters" do
      let(:filters) do
        {
          succeeded_at_from: (fee.succeeded_at - 1.minute).iso8601,
          succeeded_at_to: (fee.succeeded_at + 1.minute).iso8601
        }
      end

      let(:fee) { create(:fee, :succeeded, subscription:, invoice: nil) }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when fee is not covered by range" do
        let(:filters) do
          {
            succeeded_at_from: (fee.succeeded_at - 2.minutes).iso8601,
            succeeded_at_to: (fee.succeeded_at - 2.minutes).iso8601
          }
        end

        it "applies the filter" do
          result = fees_query.call

          expect(result).to be_success
          expect(result.fees.count).to eq(0)
        end
      end

      context "with invalid date" do
        let(:filters) { {succeeded_at_from: "invalid_date_value"} }

        it "returns a failed result" do
          result = fees_query.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:succeeded_at_from]).to include("invalid_date")
        end
      end
    end

    context "with failed_at filters" do
      let(:filters) do
        {
          failed_at_from: (fee.failed_at - 1.minute).iso8601,
          failed_at_to: (fee.failed_at + 1.minute).iso8601
        }
      end

      let(:fee) { create(:fee, :failed, subscription:, invoice: nil) }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when fee is not covered by range" do
        let(:filters) do
          {
            failed_at_from: (fee.failed_at - 2.minutes).iso8601,
            failed_at_to: (fee.failed_at - 2.minutes).iso8601
          }
        end

        it "applies the filter" do
          result = fees_query.call

          expect(result).to be_success
          expect(result.fees.count).to eq(0)
        end
      end

      context "with invalid date" do
        let(:filters) { {failed_at_from: "invalid_date_value"} }

        it "returns a failed result" do
          result = fees_query.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:failed_at_from]).to include("invalid_date")
        end
      end
    end

    context "with refunded_at filters" do
      let(:filters) do
        {
          refunded_at_from: (fee.refunded_at - 1.minute).iso8601,
          refunded_at_to: (fee.refunded_at + 1.minute).iso8601
        }
      end

      let(:fee) { create(:fee, :refunded, subscription:, invoice: nil) }

      it "applies the filter" do
        result = fees_query.call

        expect(result).to be_success
        expect(result.fees.count).to eq(1)
      end

      context "when fee is not covered by range" do
        let(:filters) do
          {
            refunded_at_from: (fee.refunded_at - 2.minutes).iso8601,
            refunded_at_to: (fee.refunded_at - 2.minutes).iso8601
          }
        end

        it "applies the filter" do
          result = fees_query.call

          expect(result).to be_success
          expect(result.fees.count).to eq(0)
        end
      end

      context "with invalid date" do
        let(:filters) { {refunded_at_from: "invalid_date_value"} }

        it "returns a failed result" do
          result = fees_query.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:refunded_at_from]).to include("invalid_date")
        end
      end
    end
  end
end
