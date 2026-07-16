# frozen_string_literal: true

RSpec.describe AiConversation do
  subject { build(:ai_conversation) }

  describe "associations" do
    it { is_expected.to belong_to(:membership) }
    it { is_expected.to belong_to(:organization) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end
end
