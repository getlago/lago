# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackable do
  describe "#set_tracing_information" do
    let(:membership) { create(:membership) }

    it "sets the membership identifier to context" do
      build_dummy(current_user: membership.user).set_tracing_information

      expect(CurrentContext.membership).to eq "membership/#{membership.id}"
    end

    context "when current organization is not present" do
      it 'sets an "unidentifiable" membership identifier to context' do
        build_dummy(current_organization: nil).set_tracing_information

        expect(CurrentContext.membership).to eq "membership/unidentifiable"
      end
    end

    context "when current user is nil" do
      it "sets the first created membership to context" do
        build_dummy(current_user: nil).set_tracing_information

        expect(CurrentContext.membership).to eq "membership/#{membership.id}"
      end
    end
  end

  def dummy_class
    Class.new do
      def self.before_action(*)
      end

      include Trackable

      def initialize(options = {})
        self.current_user = options.fetch(:current_user) if options[:current_user]
        self.current_organization = options.fetch(:current_organization)
      end

      private

      attr_accessor :current_user
      attr_accessor :current_organization
    end
  end

  def build_dummy(attrs = {})
    base_attrs = {current_organization: membership.organization}
    stub_const("DummyClass", dummy_class)
    DummyClass.new(base_attrs.merge(attrs))
  end
end
