# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe SingleParticipatorySpaceSettingsForm do
    subject { described_class.new(organization) }

    let(:organization) { create(:organization) }
    let!(:participatory_process) { create(:participatory_process, organization:, title: { en: "My Process" }) }
    let!(:proposal_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals") }
    let!(:meeting_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "meetings") }

    describe "#components_for_space" do
      it "returns only proposal components" do
        result = subject.components_for_space(participatory_process.to_gid.to_s)
        expect(result.length).to eq(1)
        expect(result.first[:id]).to eq(proposal_component.id.to_s)
      end

      it "returns empty array for blank space_gid" do
        expect(subject.components_for_space("")).to eq([])
      end
    end

    describe "#components_for_space_json" do
      it "returns JSON with only proposal components" do
        result = JSON.parse(subject.components_for_space_json)
        components = result[participatory_process.to_gid.to_s]
        expect(components.length).to eq(1)
        expect(components.first["id"]).to eq(proposal_component.id.to_s)
      end
    end
  end
end
