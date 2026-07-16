# frozen_string_literal: true

class GraphqlController < ApplicationController
  MAX_QUERY_LENGTH = 15_000

  include AuthenticableUser
  include CustomerPortalUser
  include Trackable

  before_action :set_context_source

  rescue_from JWT::ExpiredSignature do
    render_graphql_error(code: "expired_jwt_token", status: 401)
  end

  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      login_method:,
      current_user:,
      current_organization:,
      current_membership:,
      customer_portal_user:,
      request:,
      permissions: (current_membership || Permission)&.permissions_hash
    }

    CurrentContext.device_info = Utils::DeviceInfo.parse(request)

    if query.present? && query.length > MAX_QUERY_LENGTH
      return render_graphql_error(
        code: "query_is_too_large",
        status: 413,
        message: "Max query length is #{MAX_QUERY_LENGTH}, your query is #{query.length}"
      )
    end

    OpenTelemetry::Trace.current_span.add_attributes({"query" => query, "operation_name" => operation_name})
    result = LagoTracer.in_span("LagoApiSchema.execute") do
      LagoApiSchema.execute(query, variables:, context:, operation_name:)
    end

    render(json: result)
  rescue JWT::ExpiredSignature
    render_graphql_error(code: "expired_jwt_token", status: 401)
  rescue => e
    raise e unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(error)
    logger.error(error.message)
    logger.error(error.backtrace.join("\n"))

    render(json: {errors: [{message: error.message, backtrace: error.backtrace}], data: {}}, status: 500)
  end

  def render_graphql_error(code:, status:, message: nil)
    render(
      json: {
        data: {},
        errors: [
          {
            message: message || code,
            extensions: {status:, code:}
          }
        ]
      }
    )
  end

  def set_context_source
    CurrentContext.source = "graphql"
    CurrentContext.api_key_id = nil
  end
end
