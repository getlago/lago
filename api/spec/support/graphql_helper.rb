# frozen_string_literal: true

module GraphQLHelper
  def controller
    @controller ||= GraphqlController.new.tap do |ctrl|
      ctrl.set_request! ActionDispatch::Request.new({})
    end
  end

  def execute_query(query:, variables: {}, input: nil)
    if input
      variables[:input] = input
    end

    membership ||= create(:membership, organization:)

    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      current_membership: membership,
      permissions: required_permission,
      query:,
      variables:
    )
  end

  def execute_graphql(current_user: nil, query: nil, current_organization: nil, current_membership: nil, customer_portal_user: nil, request: nil, permissions: nil, **kwargs) # rubocop:disable Metrics/ParameterLists
    previous_source = CurrentContext.source
    CurrentContext.source = "graphql"

    current_membership ||= membership if defined?(membership)
    current_membership ||= current_user.memberships.active.find_by(organization: current_organization) if current_user

    unless permissions.is_a?(Hash)
      # we allow passing a single permission string or an array for convenience
      permissions = Array.wrap(permissions).index_with { true }
    end

    permissions.keys.each do |permission|
      next if Permission.permissions_hash.key?(permission)

      raise "Unknown permission: #{permission}"
    end

    args = kwargs.merge(
      context: {
        controller:,
        current_user:,
        current_organization:,
        current_membership:,
        customer_portal_user:,
        request:,
        permissions:
      }
    )

    res = LagoApiSchema.execute(
      query,
      **args
    )

    res["errors"]&.each do |e|
      if e.dig("extensions", "code") == "undefinedField" && e.dig("extensions", "fieldName").match?(/_/)
        pps "HINT: GraphQL field name should use camelCase even if its declaration is snake_case."
      end
    end

    CurrentContext.source = previous_source
    res
  end

  def expect_graphql_error(result:, message:, details: nil)
    symbolized_result = result.to_h.deep_symbolize_keys

    expect(symbolized_result[:errors]).not_to be_empty

    error = symbolized_result[:errors].find do |e|
      e[:message].to_s == message.to_s || e[:extensions][:code].to_s == message.to_s
    end

    if details
      expect(error.dig(:extensions, :details)).to eq details
    end

    errors = symbolized_result[:errors].map do |error|
      formatted_error = "- #{error[:message]}"
      if (code = error.dig(:extensions, :code))
        formatted_error += " (#{code})"
      end
      formatted_error
    end.join("\n")
    expect(error).to be_present, "error message for #{message} is not present, got:\n#{errors}"
  end

  def expect_unauthorized_error(result, details: nil)
    expect_graphql_error(
      result:,
      message: :unauthorized,
      details:
    )
  end

  def expect_forbidden_error(result, details: nil)
    expect_graphql_error(
      result:,
      message: :forbidden,
      details:
    )
  end

  def expect_unprocessable_entity(result, details: nil)
    expect_graphql_error(
      result:,
      message: :unprocessable_entity,
      details:
    )
  end

  def expect_not_found(result, details: nil)
    expect_graphql_error(
      result:,
      message: :not_found,
      details:
    )
  end
end
