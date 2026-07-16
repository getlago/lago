# frozen_string_literal: true

module BillingEntities
  class ResolveService < BaseService
    Result = BaseResult[:billing_entity]

    extend Forwardable

    def initialize(organization:, billing_entity_code: nil)
      @organization = organization
      @billing_entity_code = billing_entity_code

      super
    end

    def call
      return result.not_found_failure!(resource: "billing_entity") if organization.billing_entities.empty?

      return find_by_code if billing_entity_code.present?

      result.billing_entity = default_billing_entity
      result
    end

    private

    attr_reader :organization, :billing_entity_code
    def_delegators :organization, :default_billing_entity

    def find_by_code
      billing_entity = organization.billing_entities.find_by(code: billing_entity_code)

      return result.not_found_failure!(resource: "billing_entity") unless billing_entity

      result.billing_entity = billing_entity
      result
    end
  end
end
