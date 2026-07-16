# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiLoggable do
  # rubocop:disable RSpec/DescribedClass
  controller(ApplicationController) do
    include ApiLoggable

    attr_reader :current_organization

    def index
      render json: :ok
    end
  end
  # rubocop:enable RSpec/DescribedClass

  before do
    allow(Utils::ApiLog).to receive(:produce)
  end

  context "when get" do
    it "does not produce api log" do
      get :index

      expect(Utils::ApiLog).not_to have_received(:produce)
    end
  end

  [:post, :put, :delete].each do |method|
    context "when method is #{method}" do
      it "produces api log" do
        send(method, :index)

        expect(Utils::ApiLog).to have_received(:produce)
      end
    end
  end

  context "with skip_audit_logs!" do
    # rubocop:disable RSpec/DescribedClass
    controller(ApplicationController) do
      include ApiLoggable

      skip_audit_logs!

      def index
        render json: :ok
      end
    end
    # rubocop:enable RSpec/DescribedClass

    [:get, :post, :put, :delete].each do |method|
      context "when method is #{method}" do
        it "does not produce api log" do
          send(method, :index)

          expect(Utils::ApiLog).not_to have_received(:produce)
        end
      end
    end
  end
end
