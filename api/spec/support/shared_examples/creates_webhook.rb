# frozen_string_literal: true

RSpec.shared_examples "creates webhook" do |webhook_type, object_type, object = {}|
  it "create correct webhook model" do
    webhook_service.call

    webhook = Webhook.order(created_at: :desc).first
    expect(webhook.payload).to match({
      "webhook_type" => webhook_type,
      "object_type" => object_type,
      "organization_id" => webhook.organization_id,
      object_type => hash_including(object)
    })
  end
end
