# frozen_string_literal: true

class PasswordReset < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expire_at, presence: true
end

# == Schema Information
#
# Table name: password_resets
# Database name: primary
#
#  id         :uuid             not null, primary key
#  expire_at  :datetime         not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_password_resets_on_token    (token) UNIQUE
#  index_password_resets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
