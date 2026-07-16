# frozen_string_literal: true

RSpec.shared_examples "a configurable queue" do |dedicated_queue, env_variable, default_queue = "default"|
  let(:arguments) { nil }

  context "when #{env_variable} is true" do
    before { ENV[env_variable] = "true" }
    after { ENV.delete(env_variable) }

    it "uses the #{dedicated_queue} queue" do
      expect {
        described_class.perform_later(arguments)
      }.to have_enqueued_job.on_queue(dedicated_queue)
    end
  end

  context "when SIDEKIQ_EVENTS is false or not set" do
    before { ENV.delete(env_variable) }

    it "uses the #{default_queue} queue" do
      expect {
        described_class.perform_later(arguments)
      }.to have_enqueued_job.on_queue(default_queue)
    end
  end
end
