# frozen_string_literal: true

class ApplicationController < ActionController::API
  wrap_parameters false

  include ApiResponses

  rescue_from ActionController::RoutingError, with: :not_found
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def health
    ActiveRecord::Base.connection.execute("")
    render(
      json: {
        version: LAGO_VERSION.number,
        github_url: LAGO_VERSION.github_url,
        message: "Success"
      },
      status: :ok
    )
  rescue ActiveRecord::ActiveRecordError => e
    render(
      json: {
        version: LAGO_VERSION.number,
        github_url: LAGO_VERSION.github_url,
        message: "Unhealthy",
        details: e.message
      },
      status: :internal_server_error
    )
  end

  def ready
    if $shutdown_requested # rubocop:disable Style/GlobalVars
      render json: {status: "shutting down"}, status: :service_unavailable
    else
      render json: {status: "ok"}
    end
  end

  def not_found
    not_found_error(resource: "resource")
  end

  def append_info_to_payload(payload)
    super
    payload[:level] =
      case payload[:status].to_i
      when 200..299
        "info"
      when 400..499
        "warn"
      else
        "error"
      end
    payload[:organization_id] = current_organization&.id if defined? current_organization
  rescue
    # NOTE: Rescue potential errors on JWT token, it should break later to avoid bad responses on GraphQL
  end
end
