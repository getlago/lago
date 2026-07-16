# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::TerminateCouponsJob do
  subject { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    before { allow(Coupons::TerminateService).to receive(:terminate_all_expired) }

    it "calls Coupons::TerminateService.terminate_all_expired" do
      described_class.perform_now

      expect(Coupons::TerminateService).to have_received(:terminate_all_expired)
    end
  end
end
