# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::CreatePayInAdvanceJob do
  let(:charge) { create(:standard_charge, :pay_in_advance) }
  let(:event) { create(:event) }

  let(:result) { BaseService::Result.new }

  it "delegates to the pay_in_advance aggregation service" do
    allow(Fees::CreatePayInAdvanceService).to receive(:call)
      .with(charge:, event:, billing_at: nil)
      .and_return(result)

    described_class.perform_now(charge:, event:)

    expect(Fees::CreatePayInAdvanceService).to have_received(:call)
  end

  describe ".retry_wait" do
    it "grows polynomially and adds the jitter on each retry" do
      allow(described_class).to receive(:rand).and_return(7)

      expect(described_class.retry_wait(1)).to eq(8)  # 1**4 + 7
      expect(described_class.retry_wait(2)).to eq(23) # 2**4 + 7
      expect(described_class.retry_wait(3)).to eq(88) # 3**4 + 7
    end

    it "keeps the jitter within RETRY_JITTER" do
      jitters = Array.new(50) { described_class.retry_wait(1) - (1**4) }

      expect(jitters).to all(be_between(described_class::RETRY_JITTER.min, described_class::RETRY_JITTER.max))
    end
  end

  describe "retry_on" do
    before do
      allow(Fees::CreatePayInAdvanceService).to receive(:call)
        .and_raise(Events::Stores::Clickhouse::MemoryLimitError)
    end

    it "retries on a Clickhouse memory limit error" do
      assert_performed_jobs(25, only: [described_class]) do
        expect do
          described_class.perform_later(charge:, event:)
        end.to raise_error(Events::Stores::Clickhouse::MemoryLimitError)
      end
    end
  end
end
