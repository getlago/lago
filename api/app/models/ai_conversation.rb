# frozen_string_literal: true

class AiConversation < ApplicationRecord
  belongs_to :membership
  belongs_to :organization

  validates :name, presence: true
end

# == Schema Information
#
# Table name: ai_conversations
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  name                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  membership_id           :uuid             not null
#  mistral_conversation_id :string
#  organization_id         :uuid             not null
#
# Indexes
#
#  index_ai_conversations_on_membership_id    (membership_id)
#  index_ai_conversations_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (membership_id => memberships.id)
#  fk_rails_...  (organization_id => organizations.id)
#
