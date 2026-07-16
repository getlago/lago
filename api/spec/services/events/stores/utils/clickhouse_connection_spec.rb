# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::Utils::ClickhouseConnection do
  let(:memory_error_message) do
    "Code: 241. DB::Exception: (total) memory limit exceeded: would use 1.00 GiB (MEMORY_LIMIT_EXCEEDED)"
  end

  before { allow(described_class).to receive(:sleep) }

  describe ".with_retry" do
    it "returns the block result on success" do
      expect(described_class.with_retry { "value" }).to eq("value")
    end

    described_class::RETRYABLE_ERRORS.each do |error_class|
      it "retries up to MAX_RETRIES on #{error_class} then raises it" do
        attempts = 0

        expect do
          described_class.with_retry do
            attempts += 1
            raise error_class, "boom"
          end
        end.to raise_error(error_class)

        expect(attempts).to eq(described_class::MAX_RETRIES)
        expect(described_class).to have_received(:sleep).with(0.05).twice
      end
    end

    it "does not retry a non-retryable error" do
      attempts = 0

      expect do
        described_class.with_retry do
          attempts += 1
          raise StandardError, "boom"
        end
      end.to raise_error(StandardError, "boom")

      expect(attempts).to eq(1)
      expect(described_class).not_to have_received(:sleep)
    end

    it "re-raises a memory limit error as MemoryLimitError without retrying" do
      attempts = 0

      expect do
        described_class.with_retry do
          attempts += 1
          raise ActiveRecord::ActiveRecordError, memory_error_message
        end
      end.to raise_error(Events::Stores::Clickhouse::MemoryLimitError, memory_error_message)

      expect(attempts).to eq(1)
      expect(described_class).not_to have_received(:sleep)
    end
  end

  describe ".connection_with_retry" do
    let(:connection) { Object.new }

    before do
      allow(::Clickhouse::BaseRecord).to receive(:with_connection).and_yield(connection)
    end

    it "yields the connection and returns the block result on success" do
      expect(described_class.connection_with_retry { |conn| conn }).to eq(connection)
    end

    described_class::RETRYABLE_ERRORS.each do |error_class|
      it "retries up to MAX_RETRIES on #{error_class} then raises it" do
        attempts = 0

        expect do
          described_class.connection_with_retry do |_conn|
            attempts += 1
            raise error_class, "boom"
          end
        end.to raise_error(error_class)

        expect(attempts).to eq(described_class::MAX_RETRIES)
        expect(described_class).to have_received(:sleep).with(0.05).twice
      end
    end

    it "does not retry a non-retryable error" do
      attempts = 0

      expect do
        described_class.connection_with_retry do |_conn|
          attempts += 1
          raise StandardError, "boom"
        end
      end.to raise_error(StandardError, "boom")

      expect(attempts).to eq(1)
      expect(described_class).not_to have_received(:sleep)
    end

    it "re-raises a memory limit error as MemoryLimitError without retrying" do
      attempts = 0

      expect do
        described_class.connection_with_retry do |_conn|
          attempts += 1
          raise ActiveRecord::ActiveRecordError, memory_error_message
        end
      end.to raise_error(Events::Stores::Clickhouse::MemoryLimitError, memory_error_message)

      expect(attempts).to eq(1)
      expect(described_class).not_to have_received(:sleep)
    end
  end

  describe ".memory_limit_error?" do
    it "is true for an ActiveRecord error mentioning the memory limit code" do
      error = ActiveRecord::ActiveRecordError.new(memory_error_message)

      expect(described_class.memory_limit_error?(error)).to be(true)
    end

    it "is false for an ActiveRecord error with an unrelated message" do
      error = ActiveRecord::ActiveRecordError.new("Code: 159. DB::Exception: Timeout exceeded")

      expect(described_class.memory_limit_error?(error)).to be(false)
    end

    it "is false for a non-ActiveRecord error mentioning the memory limit code" do
      error = StandardError.new(memory_error_message)

      expect(described_class.memory_limit_error?(error)).to be(false)
    end
  end
end
