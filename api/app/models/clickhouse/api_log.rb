# frozen_string_literal: true

module Clickhouse
  class ApiLog < BaseRecord
    self.table_name = "api_logs"
    self.primary_key = nil

    belongs_to :organization
    belongs_to :api_key

    before_save :ensure_request_id

    HTTP_METHODS = {
      get: 1,
      post: 2,
      put: 3,
      delete: 4
    }.freeze

    private

    def ensure_request_id
      self.request_id = SecureRandom.uuid if request_id.blank?
    end
  end
end

# == Schema Information
#
# Table name: api_logs
# Database name: clickhouse
#
#  api_version      :string           not null
#  client           :string           not null
#  http_method      :Enum8('get' = 1, not null
#  http_status      :integer          not null
#  logged_at        :datetime         not null
#  request_body     :string           not null
#  request_origin   :string           not null
#  request_path     :string           not null
#  request_response :string
#  created_at       :datetime         not null
#  api_key_id       :string           not null
#  organization_id  :string           not null
#  request_id       :string           not null
#
