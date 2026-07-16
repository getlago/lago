# frozen_string_literal: true

class UserDevice < ApplicationRecord
  belongs_to :user

  validates :fingerprint, uniqueness: {scope: :user_id}
end

# == Schema Information
#
# Table name: user_devices
# Database name: primary
#
#  id              :uuid             not null, primary key
#  browser         :string
#  device_type     :string
#  fingerprint     :string           not null
#  last_ip_address :string
#  last_logged_at  :datetime         not null
#  os              :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_user_devices_on_user_id_and_fingerprint  (user_id,fingerprint) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
