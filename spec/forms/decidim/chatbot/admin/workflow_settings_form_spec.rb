# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe WorkflowSettingsForm do
    subject { described_class.new(organization) }

    let(:organization) { create(:organization) }
    let!(:participatory_process) { create(:participatory_process, organization:, title: { en: "My Process" }) }
    let!(:assembly) { create(:assembly, organization:, title: { en: "My Assembly" }) }
    let!(:proposal_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals") }

    describe "#participatory_space_options" do
      it "returns grouped participatory spaces" do
        result = subject.participatory_space_options
        expect(result).to be_a(Hash)
        expect(result.keys).to include("Participatory processes")
      end
    end

    describe "#components_for_space" do
      it "returns all published components for the given space" do
        meeting_component = create(:component, :published, participatory_space: participatory_process, manifest_name: "meetings")
        result = subject.components_for_space(participatory_process.to_gid.to_s)
        expect(result.length).to eq(2)
        expect(result.map { |component| component[:id] }).to contain_exactly(proposal_component.id.to_s, meeting_component.id.to_s)
      end

      it "includes manifest_name in returned data" do
        result = subject.components_for_space(participatory_process.to_gid.to_s)
        expect(result.first[:manifest_name]).to eq("proposals")
      end

      it "returns empty array for blank space_gid" do
        expect(subject.components_for_space("")).to eq([])
      end
    end

    describe "#components_for_space_json" do
      it "returns JSON with all components grouped by space gid" do
        meeting_component = create(:component, :published, participatory_space: participatory_process, manifest_name: "meetings")
        result = JSON.parse(subject.components_for_space_json)
        components = result[participatory_process.to_gid.to_s]
        expect(components.length).to eq(2)
        expect(components.map { |component| component["id"] }).to contain_exactly(proposal_component.id.to_s, meeting_component.id.to_s)
      end
    end
  end
end
