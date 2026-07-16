# frozen_string_literal: true

# ExecutionErrorResponder Module
module ExecutionErrorResponder
  extend ActiveSupport::Concern

  private

  def execution_error(error: "Internal Error", status: 422, code: "internal_error", details: nil)
    payload = {
      status:,
      code:
    }

    if details.is_a?(Hash)
      payload[:details] = details&.transform_keys do |key|
        key.to_s.camelize(:lower)
      end
    end

    GraphQL::ExecutionError.new(error, extensions: payload)
  end

  def not_found_error(resource:)
    execution_error(
      error: "Resource not found",
      status: 404,
      code: "not_found",
      details: {
        resource => ["not_found"]
      }
    )
  end

  def not_allowed_error(code:)
    execution_error(
      error: "Method Not Allowed",
      status: 405,
      code:
    )
  end

  def forbidden_error(code:)
    execution_error(
      error: "forbidden",
      status: 403,
      code:
    )
  end

  def validation_error(messages:)
    execution_error(
      error: "Unprocessable Entity",
      status: 422,
      code: "unprocessable_entity",
      details: messages
    )
  end

  def third_party_failure(messages:)
    execution_error(
      error: "Unprocessable Entity",
      status: 422,
      code: "third_party_error",
      details: {error: messages}
    )
  end

  def result_error(service_result)
    case service_result.error
    when BaseService::NotFoundFailure
      not_found_error(resource: service_result.error.resource)
    when BaseService::MethodNotAllowedFailure
      not_allowed_error(code: service_result.error.code)
    when BaseService::ValidationFailure
      validation_error(messages: service_result.error.messages)
    when BaseService::ForbiddenFailure
      forbidden_error(code: service_result.error.code)
    when BaseService::ThirdPartyFailure
      third_party_failure(messages: service_result.error.message)
    else
      execution_error(
        error: "Internal error",
        status: 500,
        code: service_result.error.code
      )
    end
  end
end
