# frozen_string_literal: true

module Api
  module V1
    module Plans
      class BaseController < Api::BaseController
        before_action :find_plan

        private

        attr_reader :plan

        def find_plan
          @plan = current_organization.plans.parents.find_by!(
            code: params[:plan_code]
          )
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "plan")
        end

        def resource_name
          "plan"
        end
      end
    end
  end
end
