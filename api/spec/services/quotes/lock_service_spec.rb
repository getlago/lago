# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::LockService do
  let(:lock_service) { described_class.new(quote:, timeout_seconds:) }
  let(:quote) { create(:quote) }
  let(:timeout_seconds) { 5.seconds }

  describe "#call" do
    context "when lock can be acquired" do
      it "takes an advisory lock" do
        expect(ActiveRecord::Base.advisory_lock_exists?("quote-#{quote.id}")).to be false

        lock_service.call do
          expect(ActiveRecord::Base.advisory_lock_exists?("quote-#{quote.id}")).to be true
        end

        expect(ActiveRecord::Base.advisory_lock_exists?("quote-#{quote.id}")).to be false
      end

      it "yields the block return value" do
        expect(lock_service.call { :done }).to eq(:done)
      end
    end

    context "when lock cannot be acquired", transaction: false do
      let(:timeout_seconds) { 0.seconds }

      around do |test|
        with_advisory_lock("quote-#{quote.id}", lock_released_after: 2.seconds) do
          test.run
        end
      end

      it "raises a Customers::FailedToAcquireLock error" do
        expect do
          lock_service.call { nil }
        end.to raise_error(Customers::FailedToAcquireLock, "Failed to acquire lock quote-#{quote.id}")
      end
    end
  end

  describe "reentrancy" do
    it "re-enters the same quote lock without blocking and keeps it held" do
      inner_result = nil

      described_class.call(quote:, timeout_seconds: 0) do
        # Nested acquisition of the same quote lock succeeds immediately (timeout: 0
        # would otherwise fail fast) because the gem short-circuits on already_locked?.
        inner_result = described_class.call(quote:, timeout_seconds: 0) { :inner }

        # The lock is still held after the nested block returns.
        expect(ActiveRecord::Base.advisory_lock_exists?("quote-#{quote.id}")).to be true
      end

      expect(inner_result).to eq(:inner)
    end

    it "allows nesting a lock on a different quote" do
      other_quote = create(:quote)
      inner_ran = false

      described_class.call(quote:) do
        described_class.call(quote: other_quote) { inner_ran = true }
      end

      expect(inner_ran).to be true
    end
  end
end
