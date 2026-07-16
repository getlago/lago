# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::LockService do
  let(:lock_service) { described_class.new(customer:, scope: :prepaid_credit, timeout_seconds:) }
  let(:customer) { create(:customer) }
  let(:timeout_seconds) { 5.seconds }

  describe ".new" do
    context "with invalid scope" do
      it "raises ArgumentError" do
        expect do
          described_class.new(customer:, scope: :invalid_scope)
        end.to raise_error(ArgumentError, /Invalid scope: invalid_scope/)
      end
    end
  end

  describe "#call" do
    subject { lock_service.call }

    context "when lock can be acquired" do
      it "takes an advisory lock" do
        expect(lock_service).not_to be_locked

        lock_service.call do
          expect(lock_service).to be_locked
        end

        expect(lock_service).not_to be_locked
      end
    end

    context "when lock cannot be acquired", transaction: false do
      let(:timeout_seconds) { 0.seconds }

      around do |test|
        with_advisory_lock("customer-#{customer.id}-prepaid_credit", lock_released_after: 2.seconds) do
          test.run
        end
      end

      it "raises a Customers::FailedToAcquireLock error" do
        expect do
          lock_service.call { nil }
        end.to raise_error(Customers::FailedToAcquireLock, "Failed to acquire lock customer-#{customer.id}-prepaid_credit")
      end
    end
  end

  describe "#locked?" do
    subject { lock_service.locked? }

    context "when the lock is taken" do
      it "returns true" do
        lock_service.call do
          expect(subject).to be true
        end
      end
    end

    context "when the lock is not taken" do
      it "returns false" do
        expect(subject).to be false
      end
    end
  end
end
