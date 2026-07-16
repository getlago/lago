# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Events::ValidationErrorsService do
  subject(:webhook_service) { described_class.new(object: organization, options:) }

  let(:organization) { create(:organization) }

  let(:options) do
    {
      errors: {
        invalid_code: [SecureRandom.uuid],
        missing_aggregation_property: [SecureRandom.uuid],
        missing_group_key: [SecureRandom.uuid]
      }
    }
  end

  describe ".call" do
    it_behaves_like "creates webhook", "events.errors", "events_errors", {
      "invalid_code" => Array,
      "missing_aggregation_property" => Array,
      "missing_group_key" => Array
    }
  end
end
