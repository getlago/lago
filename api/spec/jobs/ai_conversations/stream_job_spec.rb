# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiConversations::StreamJob do
  let(:ai_conversation) { create(:ai_conversation) }
  let(:message) { Faker::Lorem.word }

  before do
    allow(AiConversations::StreamService).to receive(:call).with(ai_conversation:, message:)
  end

  it "calls the service" do
    described_class.perform_now(ai_conversation:, message:)

    expect(AiConversations::StreamService).to have_received(:call)
  end
end
