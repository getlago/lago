# frozen_string_literal: true

module OrderForms
  module Premium
    extend ActiveSupport::Concern

    private

    def order_forms_enabled?(organization)
      License.premium? && organization.feature_flag_enabled?(:order_forms)
    end
  end
end
