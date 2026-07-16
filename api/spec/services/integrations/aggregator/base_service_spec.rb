# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::BaseService do
  subject(:sync_service) { described_class.new(integration:) }

  let(:integration) { create(:netsuite_integration) }

  describe "#request_limit_error?" do
    let(:http_error) { instance_double(LagoHttpClient::HttpError, error_body:) }

    context "when error body includes request limit error code" do
      let(:error_body) { "Some error message including SSS_REQUEST_LIMIT_EXCEEDED" }

      it "returns true" do
        expect(sync_service.send(:request_limit_error?, http_error)).to be true
      end
    end

    context "when error body does not include request limit error code" do
      let(:error_body) { "Some other error message" }

      it "returns false" do
        expect(sync_service.send(:request_limit_error?, http_error)).to be false
      end
    end
  end
end
