# frozen_string_literal: true

module Entitlement
  class FeaturesQuery < BaseQuery
    Result = BaseResult[:features]

    def call
      features = base_scope.result
      features = paginate(features)
      features = apply_consistent_ordering(features)

      result.features = features
      result
    end

    private

    def base_scope
      Feature.where(organization:).ransack(search_params)
    end

    def search_params
      return if search_term.blank?

      {
        m: "or",
        name_cont: search_term,
        code_cont: search_term,
        description_cont: search_term
      }
    end
  end
end
