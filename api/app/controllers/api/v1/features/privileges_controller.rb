# frozen_string_literal: true

module Api
  module V1
    module Features
      class PrivilegesController < Api::BaseController
        def destroy
          feature = current_organization.features.find_by(code: params[:feature_code])
          return not_found_error(resource: "feature") unless feature

          privilege = feature.privileges.where(code: params[:code]).first
          return not_found_error(resource: "privilege") unless privilege

          result = ::Entitlement::PrivilegeDestroyService.call(privilege:)

          if result.success?
            render(
              json: ::V1::Entitlement::FeatureSerializer.new(
                feature,
                root_name:
              )
            )
          else
            render_error_response(result)
          end
        end

        private

        def root_name
          "feature"
        end

        def resource_name
          "feature"
        end
      end
    end
  end
end
