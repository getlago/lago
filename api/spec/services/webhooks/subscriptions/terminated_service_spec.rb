# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Subscriptions::TerminatedService do
  subject(:webhook_service) { described_class.new(object: subscription) }

  let(:subscription) { create(:subscription, status: :terminated, terminated_at: Time.current) }
  let(:organization) { subscription.organization }

  describe ".call" do
    it_behaves_like "creates webhook", "subscription.terminated", "subscription"
  end
end
