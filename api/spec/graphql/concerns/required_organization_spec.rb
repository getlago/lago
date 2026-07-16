# frozen_string_literal: true

require "rails_helper"

module RequiredOrganizationSpec
  class ThingType < Types::BaseObject
    field :name, String, null: false
    field :count, Integer
  end

  class RenameThingMutation < Mutations::BaseMutation
    include RequiredOrganization

    graphql_name "RenameThing"
    argument :new_name, String, required: true
    type ThingType

    def resolve(**args)
      {name: args[:new_name], count: 1}
    end
  end

  class ThingsMutationType < Types::BaseObject
    field :renameThing, mutation: RenameThingMutation
  end

  class TestApiSchema < LagoApiSchema
    mutation(ThingsMutationType)
  end
end

RSpec.describe RequiredOrganization do
  let(:mutation) do
    <<-GQL
      mutation($input: RenameThingInput!) {
        renameThing(input: $input) {
          name
        }
      }
    GQL
  end

  context "with a current organization and a member" do
    it "renames the thing" do
      membership = create(:membership)

      result = RequiredOrganizationSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {current_user: membership.user, current_organization: membership.organization, current_membership: membership}
      )

      expect(result["data"]["renameThing"]["name"]).to eq "new name"
    end
  end

  context "without a current organization" do
    it "returns an error" do
      result = RequiredOrganizationSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {current_user: create(:user), permissions: Permission.permissions_hash(:admin)}
      )

      partial_error = {
        "message" => "Missing organization id",
        "extensions" => {"status" => :forbidden, "code" => "forbidden"}
      }

      expect(result["errors"]).to include hash_including(partial_error)
    end
  end

  context "without a current organization but the current is not a member" do
    it "returns an error" do
      membership = create(:membership)

      result = RequiredOrganizationSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {current_user: membership.user, current_membership: membership, current_organization: create(:organization)}
      )

      partial_error = {
        "message" => "Not in organization",
        "extensions" => {"status" => :forbidden, "code" => "forbidden"}
      }

      expect(result["errors"]).to include hash_including(partial_error)
    end
  end

  context "when a current membership is not set in context" do
    it "returns an error" do
      result = RequiredOrganizationSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {current_user: create(:user), current_organization: create(:organization)}
      )

      partial_error = {
        "message" => "Missing membership",
        "extensions" => {"status" => :forbidden, "code" => "forbidden"}
      }

      expect(result["errors"]).to include hash_including(partial_error)
    end
  end
end
