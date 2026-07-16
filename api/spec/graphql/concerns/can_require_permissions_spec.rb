# frozen_string_literal: true

require "rails_helper"

module CanRequirePermissionsSpec
  class ThingType < Types::BaseObject
    field :name, String, null: false
    field :count, Integer
  end

  class RenameThingMutation < Mutations::BaseMutation
    include CanRequirePermissions

    REQUIRED_PERMISSION = "things:rename"

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

RSpec.describe CanRequirePermissions do
  let(:mutation) do
    <<-GQL
      mutation($input: RenameThingInput!) {
        renameThing(input: $input) {
          name
        }
      }
    GQL
  end

  context "with a the correct permissions" do
    it "renames the thing" do
      result = CanRequirePermissionsSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {permissions: {"things:rename" => true}}
      )

      expect(result["data"]["renameThing"]["name"]).to eq "new name"
    end
  end

  context "without a current user" do
    it "returns an error" do
      result = CanRequirePermissionsSpec::TestApiSchema.execute(
        mutation,
        variables: {input: {newName: "new name"}},
        context: {permissions: Permission.permissions_hash}
      )

      partial_error = {
        "message" => "Missing permissions",
        "extensions" => {"status" => :forbidden, "code" => "forbidden", "required_permissions" => ["things:rename"]}
      }

      expect(result["errors"]).to include hash_including(partial_error)
    end
  end
end
