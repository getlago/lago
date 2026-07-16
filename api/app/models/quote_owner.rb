# frozen_string_literal: true

class QuoteOwner < ApplicationRecord
  belongs_to :organization
  belongs_to :quote
  belongs_to :user
end

# == Schema Information
#
# Table name: quote_owners
# Database name: primary
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  quote_id        :uuid             not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_quote_owners_on_organization_id    (organization_id)
#  index_quote_owners_on_user_id            (user_id)
#  index_unique_quote_owners_on_quote_user  (quote_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (quote_id => quotes.id)
#  fk_rails_...  (user_id => users.id)
#
