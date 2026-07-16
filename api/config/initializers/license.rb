# frozen_string_literal: true

require "lago_utils"

License = LagoUtils::License.new(Rails.application.config.license_url)

License.verify unless Rails.env.test?
