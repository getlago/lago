# frozen_string_literal: true

module Admin
  module Organizations
    class UpdateService < ::BaseService
      Result = BaseResult[:organization]

      def initialize(organization:, params:)
        @organization = organization
        @params = params

        super
      end

      def call
        return result.not_found_failure!(resource: "organization") unless organization

        organization.name = params[:name] if params.key?(:name)
        organization.premium_integrations = params[:premium_integrations] if params.key?(:premium_integrations)

        organization.save!

        result.organization = organization
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :organization, :params
    end
  end
end
