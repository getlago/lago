# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuoteVersions::VoidService do
  subject(:void_service) { described_class.new(quote_version:, reason:) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:quote_version) { create(:quote_version, organization:) }
  let(:reason) { "manual" }

  describe ".call" do
    let(:result) { void_service.call }

    context "when quote is voidable", :premium do
      it "voids the quote version" do
        freeze_time do
          expect(result).to be_success
          expect(result.quote_version.voided?).to eq(true)
          expect(result.quote_version.void_reason).to eq(reason)
          expect(result.quote_version.voided_at).to eq(Time.current)
          expect(result.quote_version.share_token).to eq(nil)
          expect(result.quote_version.approved_at).to eq(nil)
        end
      end
    end

    context "with concurrent mutations", :premium do
      it "wraps the work in a per-quote lock" do
        allow(Quotes::LockService).to receive(:call).and_call_original

        result

        expect(Quotes::LockService).to have_received(:call).with(quote: quote_version.quote).at_least(:once)
      end

      it "re-checks the status under the lock and refuses a stale void" do
        quote_version
        QuoteVersion.find(quote_version.id).update!(status: :approved, approved_at: Time.current)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({status: ["not_voidable"]})
      end
    end

    context "when quote version is approved", :premium do
      let(:quote_version) { create(:quote_version, :approved, organization:) }

      it "is not voidable" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({status: ["not_voidable"]})
      end
    end

    context "when quote version is approved and reason is a cascade", :premium do
      let(:quote_version) { create(:quote_version, :approved, organization:) }
      let(:reason) { "cascade_of_expired" }

      it "voids the quote version" do
        freeze_time do
          expect(result).to be_success
          expect(result.quote_version.voided?).to eq(true)
          expect(result.quote_version.void_reason).to eq("cascade_of_expired")
          expect(result.quote_version.voided_at).to eq(Time.current)
        end
      end
    end

    context "when quote isn't voidable", :premium do
      let(:quote_version) { create(:quote_version, :voided, organization:) }

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages).to eq({status: ["not_voidable"]})
      end
    end

    context "when reason is invalid", :premium do
      context "when reason is blank" do
        let(:reason) { nil }

        it "returns validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:void_reason]).to eq(["invalid"])
        end
      end

      context "when reason is undefined" do
        let(:reason) { "invalid_reason" }

        it "returns validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:void_reason]).to eq(["invalid"])
        end
      end
    end

    context "when quote_version does not exist", :premium do
      let(:quote_version) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_version_not_found")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end
  end
end
