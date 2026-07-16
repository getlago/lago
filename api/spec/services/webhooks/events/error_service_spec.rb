# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Events::ErrorService do
  subject(:webhook_service) { described_class.new(object: event, options:) }

  let(:organization) { create(:organization) }
  let(:event) { create(:received_event, organization_id: organization.id) }
  let(:options) { {error: {transaction_id: ["value_already_exist"]}} }

  describe ".call" do
    it_behaves_like "creates webhook", "event.error", "event_error", {"error" => String, "event" => Hash}
  end
end
