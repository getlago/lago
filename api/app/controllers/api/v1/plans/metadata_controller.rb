# frozen_string_literal: true

module Api
  module V1
    module Plans
      class MetadataController < BaseController
        def create
          result = ::Plans::UpdateService.call(plan:, params: metadata_params)

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        def update
          result = ::Plans::UpdateService.call(plan:, partial_metadata: true, params: metadata_params)

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        def destroy
          result = ::Plans::UpdateService.call(plan:, params: {metadata: nil})

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        def destroy_key
          return not_found_error(resource: "metadata") unless plan.metadata

          result = Metadata::DeleteItemKeyService.call(item: plan.metadata, key: params[:key])

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        private

        def metadata_params
          params.permit(metadata: {}).to_h
        end

        def render_metadata
          render(json: {metadata: plan.reload.metadata&.value})
        end
      end
    end
  end
end
