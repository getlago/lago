# frozen_string_literal: true

require "rails_helper"

module AuthenticableCustomerPortalUserSpec
  class ThingType < Types::BaseObject
    field :name, String, null: false
  end

  class ThingResolver < Resolvers::BaseResolver
    include AuthenticableCustomerPortalUser

    type ThingType, null: false

    def resolve(**_args)
      {name: "something", count: 1}
    end
  end

  class ThingsQueryType < Types::BaseObject
    field :thing, resolver: ThingResolver
  end

  class TestApiSchema < LagoApiSchema
    query(ThingsQueryType)
  end
end

RSpec.describe AuthenticableCustomerPortalUser do
  let(:resolver) do
    <<~GQL
      query {
        thing {
          name
        }
      }
    GQL
  end

  context "with a customer portal user" do
    it "resolvers the thing" do
      result = AuthenticableCustomerPortalUserSpec::TestApiSchema.execute(
        resolver,
        context: {customer_portal_user: create(:user)}
      )

      expect(result["data"]["thing"]).to eq "name" => "something"
    end
  end

  context "without a current user" do
    it "returns an error" do
      result = AuthenticableCustomerPortalUserSpec::TestApiSchema.execute(
        resolver,
        context: {permissions: Permission.permissions_hash(:admin)}
      )

      partial_error = {
        "message" => "unauthorized",
        "extensions" => {"status" => :unauthorized, "code" => "unauthorized"}
      }

      expect(result["errors"]).to include hash_including(partial_error)
    end
  end
end
