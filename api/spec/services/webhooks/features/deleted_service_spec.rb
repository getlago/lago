# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Features::DeletedService do
  subject(:webhook_service) { described_class.new(object: feature, options:) }

  let(:organization) { create(:organization) }
  let(:feature) { create(:feature, organization:) }
  let(:options) { {} }

  describe ".call" do
    it_behaves_like "creates webhook", "feature.deleted", "feature", {
      "code" => String,
      "name" => String,
      "description" => String,
      "privileges" => Array,
      "created_at" => String
    }
  end
end
