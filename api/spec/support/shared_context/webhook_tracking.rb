# frozen_string_literal: true

RSpec.shared_context "with webhook tracking" do
  let(:webhooks_sent) { [] }

  before do
    webhook_url = organization.webhook_endpoints.sole.webhook_url

    stub_request(:post, webhook_url).with do |req|
      webhooks_sent << JSON.parse(req.body).with_indifferent_access
      true
    end.and_return(status: 200)
  rescue ActiveRecord::SoleRecordExceeded
    raise "`with webhook tracking` shared context only works with a single webhook endpoint"
  end
end
