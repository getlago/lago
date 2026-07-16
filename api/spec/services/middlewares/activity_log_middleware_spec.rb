# frozen_string_literal: true

RSpec.describe Middlewares::ActivityLogMiddleware do
  let(:service_class) do
    action = activity_loggable_action
    after_commit = activity_loggable_after_commit
    Class.new(BaseService) do
      const_set(:Result, BaseResult[:subscription])

      activity_loggable(action: action, record: -> { subscription }, after_commit:)

      def initialize(subscription:)
        @subscription = subscription
        super()
      end

      def call
        subscription.update!(name: "Updated Subscription")

        result.subscription = subscription
        result
      end

      private

      attr_reader :subscription
    end
  end

  let(:subscription) { create(:subscription, name: "My Subscription") }
  let(:activity_loggable_after_commit) { false }

  def test_service_with_activity_loggable(after_commit:, action_match_updated: false)
    expect(service_class).to use_middleware(described_class)

    allow(Utils::ActivityLog).to receive(:produce).and_wrap_original do |m, *args, **kwargs, &block|
      if action_match_updated
        # For "updated" actions, `Utils::ActivityLog#produce` will execute `BaseService#call` method so subscription is not yet updated here
        expect(subscription.name).to eq("My Subscription")
      else
        # For other actions, `Utils::ActivityLog#produce` is executed after `BaseService#call` method so subscription is already updated here
        expect(subscription.name).to eq("Updated Subscription")
      end

      result = m.call(*args, **kwargs, &block)

      # Test that `Utils::ActivityLog#produce` returns the result of the service call
      expect(result).to be_success
      expect(result.subscription).to eq(subscription)
      expect(result.subscription.name).to eq("Updated Subscription")

      result
    end

    result = service_class.call(subscription:)

    expect(Utils::ActivityLog).to have_received(:produce).with(subscription, activity_loggable_action, after_commit:)

    expect(result).to be_success
    expect(result.subscription).to eq(subscription)
    expect(result.subscription.name).to eq("Updated Subscription")
  end

  context "when action matches /updated/" do
    let(:activity_loggable_action) { "subscription.updated" }

    context "when after_commit is true" do
      let(:activity_loggable_after_commit) { true }

      it "produces the activity log after commit" do
        test_service_with_activity_loggable(after_commit: true, action_match_updated: true)
      end
    end

    context "when after_commit is false" do
      let(:activity_loggable_after_commit) { false }

      it "produces the activity log before commit" do
        test_service_with_activity_loggable(after_commit: false, action_match_updated: true)
      end
    end
  end

  context "when action does not match /updated/" do
    let(:activity_loggable_action) { "subscription.created" }

    context "when after_commit is true" do
      let(:activity_loggable_after_commit) { true }

      it "produces the activity log" do
        test_service_with_activity_loggable(after_commit: true, action_match_updated: false)
      end
    end

    context "when after_commit is false" do
      let(:activity_loggable_after_commit) { false }

      it "produces the activity log" do
        test_service_with_activity_loggable(after_commit: false, action_match_updated: false)
      end
    end
  end
end
