# frozen_string_literal: true

require "rails_helper"
require_relative "../../../dev/sidekiq/profiling_middleware"

RSpec.describe Sidekiq::ProfilingMiddleware do
  subject(:middleware) { described_class.new(**options) }

  let(:test_dir) { "tmp/test_profiling_#{SecureRandom.hex(4)}" }
  let(:options) { {dir: test_dir} }
  let(:instance) { nil }
  let(:queue) { "default" }
  let(:job_hash) do
    {
      "class" => "TestJob",
      "jid" => "test_jid_123",
      "enqueued_at" => Time.current.to_f
    }
  end

  def test_method_to_profile
    value = 0
    200_000.times { value += 1 }
    value
  end

  around do |example|
    FileUtils.rm_rf(test_dir)
    example.run
  ensure
    FileUtils.rm_rf(test_dir)
  end

  describe "#call" do
    let(:block) { -> { test_method_to_profile } }

    it "generates profile files" do
      result = middleware.call(instance, job_hash, queue, &block)

      expect(result).to eq(200_000)

      profile_dir = "#{test_dir}/TestJob"

      expect(Dir.exist?(profile_dir)).to be(true)

      files = Dir.glob("#{profile_dir}/*.json")
      expect(files.length).to eq 1

      profiling_content = File.read(files.first)

      expect(profiling_content).to include("test_method_to_profile")
    end

    context "with wrapped job class" do
      let(:job_hash) do
        {
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "wrapped" => "MyWrappedJob",
          "jid" => "wrapped_jid_456",
          "enqueued_at" => Time.current.to_f
        }
      end

      it "generates profile files with wrapped job name" do
        result = middleware.call(instance, job_hash, queue, &block)

        expect(result).to eq(200_000)

        profile_dir = "#{test_dir}/MyWrappedJob"

        expect(Dir.exist?(profile_dir)).to be(true)

        files = Dir.glob("#{profile_dir}/*.json")
        expect(files.length).to eq 1

        profiling_content = File.read(files.first)

        expect(profiling_content).to include("test_method_to_profile")
      end
    end
  end
end
