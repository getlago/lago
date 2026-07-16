# frozen_string_literal: true

RSpec.shared_examples "requires current user" do
  it "requires a current user" do
    expect(described_class.ancestors).to include(AuthenticableApiUser)
  end
end

RSpec.shared_examples "requires current organization" do
  it "requires a current organization" do
    expect(described_class.ancestors).to include(RequiredOrganization)
  end
end

RSpec.shared_examples "requires permission" do |permission|
  it "requires #{permission} permission" do
    actual = Array.wrap(described_class::REQUIRED_PERMISSION).sort
    expected = Array.wrap(permission).sort
    expect(actual).to eq expected
  end
end

RSpec.shared_examples "requires Premium license" do
  it "returns an error" do
    allow(License).to receive(:premium?).and_return(false)

    expect_graphql_error(
      result: subject,
      message: "forbidden"
    )
    expect(License).to have_received(:premium?)
  end
end

RSpec.shared_examples "requires a customer portal user" do
  it "requires a customer portal user" do
    expect(described_class.ancestors).to include(AuthenticableCustomerPortalUser)
  end
end
