# frozen_string_literal: true

class CurrentContext < ActiveSupport::CurrentAttributes
  attribute :membership, :source, :email, :api_key_id, :device_info
end
