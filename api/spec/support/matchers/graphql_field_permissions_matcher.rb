# frozen_string_literal: true

# Usage:
#  it { is_expected.to have_a_field(:api_key).with_permissions('developers:manage') }
#
module RSpec
  module GraphqlMatchers
    module WithPermissions
      def with_permissions(expected_permissions)
        @expectations << WithPermissionsMatcher.new(expected_permissions)
        self
      end
      alias_method :with_permission, :with_permissions
    end

    class HaveAField < BaseMatcher
      include WithPermissions
    end

    class AcceptArgument < BaseMatcher
      include WithPermissions
    end

    class WithPermissionsMatcher
      def initialize(expected_permissions)
        @expected_permissions = Array.wrap(expected_permissions)
      end

      def description
        "with permissions `#{@expected_permissions}`"
      end

      def matches?(actual)
        @actual_permissions = actual.permissions
        @actual_permissions.sort == @expected_permissions.sort
      end

      def failure_message
        "#{description}, but it was `#{@actual_permissions}`"
      end
    end
  end
end
