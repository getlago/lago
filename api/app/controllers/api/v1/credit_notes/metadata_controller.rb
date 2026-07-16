# frozen_string_literal: true

module Api
  module V1
    module CreditNotes
      class MetadataController < BaseController
        def create
          result = ::CreditNotes::UpdateService.call(credit_note:, metadata:)

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        def update
          result = ::CreditNotes::UpdateService.call(credit_note:, partial_metadata: true, metadata:)

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        def destroy
          result = ::CreditNotes::UpdateService.call(credit_note:, metadata: nil)

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        def destroy_key
          return not_found_error(resource: "metadata") unless credit_note.metadata

          result = Metadata::DeleteItemKeyService.call(item: credit_note.metadata, key: params[:key])

          if result.success?
            render_metadata
          else
            render_error_response(result)
          end
        end

        private

        def metadata
          params.fetch(:metadata, {}).permit!.to_h
        end

        def render_metadata
          render(json: {metadata: credit_note.reload.metadata&.value})
        end
      end
    end
  end
end
