# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhook do
  subject(:inbound_webhook) { build(:inbound_webhook) }

  it { is_expected.to belong_to(:organization) }

  it { is_expected.to validate_presence_of(:event_type) }
  it { is_expected.to validate_presence_of(:payload) }
  it { is_expected.to validate_presence_of(:source) }
  it { is_expected.to validate_presence_of(:status) }

  it { is_expected.to be_pending }

  describe "#processing!" do
    it "updates status and processing_at" do
      freeze_time do
        expect { inbound_webhook.processing! }
          .to change(inbound_webhook, :status).to("processing")
          .and change(inbound_webhook, :processing_at).to(Time.zone.now)
      end
    end
  end
end
