# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreditNotes::DownloadXml do
  let(:required_permission) { "credit_notes:view" }
  let(:credit_note) { create(:credit_note) }
  let(:organization) { credit_note.organization }
  let(:membership) { create(:membership, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: DownloadXmlCreditNoteInput!) {
        downloadXmlCreditNote(input: $input) {
          id
          xmlUrl
        }
      }
    GQL
  end

  before do
    credit_note.xml_file.attach(
      io: StringIO.new(File.read(Rails.root.join("spec/fixtures/blank.xml"))),
      filename: "credit_note.xml",
      content_type: "application/xml"
    )
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "credit_notes:view"

  it "generates the credit note XML" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          id: credit_note.id
        }
      }
    )

    result_data = result["data"]["downloadXmlCreditNote"]

    expect(result_data["id"]).to eq(credit_note.id)
    expect(result_data["xmlUrl"]).to be_present
  end
end
