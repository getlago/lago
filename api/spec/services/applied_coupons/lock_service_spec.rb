# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedCoupons::LockService do
  subject(:lock_service) { described_class.new(customer:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  describe "#call" do
    it "takes an advisory lock" do
      expect(lock_service).not_to be_locked

      lock_service.call do
        expect(lock_service).to be_locked
      end

      expect(lock_service).not_to be_locked
    end
  end
end
