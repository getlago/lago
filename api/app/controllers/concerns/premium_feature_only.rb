# frozen_string_literal: true

module PremiumFeatureOnly
  extend ActiveSupport::Concern

  included do
    before_action :ensure_premium_license
  end

  private

  def ensure_premium_license
    forbidden_error(code: "feature_unavailable") unless License.premium?
  end
end
