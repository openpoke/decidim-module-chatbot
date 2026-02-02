# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe ApplicationHelper do
    let(:organization) { create(:organization) }
    let!(:participatory_process) { create(:participatory_process, organization:, title: { en: "My Process" }) }
    let!(:assembly) { create(:assembly, organization:, title: { en: "My Assembly" }) }
    let!(:proposal_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals") }
    let!(:another_component) { create(:component, :published, participatory_space: assembly, manifest_name: "proposals") }

    before do
      allow(helper).to receive(:current_organization).and_return(organization)
    end

    describe "#participatory_space_options" do
      it "returns grouped participatory spaces" do
        result = helper.participatory_space_options(organization)
        expect(result).to be_a(Hash)
      end

      it "groups spaces by type" do
        result = helper.participatory_space_options(organization)
        expect(result.keys).to include("Participatory processes")
        expect(result.keys).to include("Assemblies")
      end

      it "returns space title and gid pairs" do
        result = helper.participatory_space_options(organization)
        process_options = result["Participatory processes"]
        expect(process_options).to include(["My Process", participatory_process.to_gid.to_s])
      end
    end

    describe "#components_for_space" do
      it "returns components for the given space" do
        result = helper.components_for_space(participatory_process.to_gid.to_s, organization)
        expect(result).to be_an(Array)
        expect(result.first[:id]).to eq(proposal_component.id.to_s)
      end

      it "returns empty array for blank space_gid" do
        result = helper.components_for_space("", organization)
        expect(result).to eq([])
      end

      it "returns empty array for invalid space_gid" do
        result = helper.components_for_space("invalid-gid", organization)
        expect(result).to eq([])
      end

      it "only returns proposal components" do
        create(:component, :published, participatory_space: participatory_process, manifest_name: "meetings")
        result = helper.components_for_space(participatory_process.to_gid.to_s, organization)
        expect(result.length).to eq(1)
        expect(result.first[:id]).to eq(proposal_component.id.to_s)
      end
    end

    describe "#components_for_space_json" do
      it "returns JSON with components grouped by space gid" do
        result = JSON.parse(helper.components_for_space_json(organization))
        expect(result).to be_a(Hash)
        expect(result[participatory_process.to_gid.to_s]).to be_an(Array)
      end

      it "includes component id and name" do
        result = JSON.parse(helper.components_for_space_json(organization))
        component_data = result[participatory_process.to_gid.to_s].first
        expect(component_data["id"]).to eq(proposal_component.id.to_s)
        expect(component_data["name"]).to be_present
      end
    end

    describe "#delegate_workflow_options" do
      it "returns workflow options" do
        result = helper.delegate_workflow_options
        expect(result).to be_an(Array)
        expect(result.first).to be_an(Array)
        expect(result.first.length).to eq(2)
      end

      it "includes registered workflows" do
        result = helper.delegate_workflow_options
        workflow_names = result.map(&:last)
        expect(workflow_names).to include("organization_welcome")
        expect(workflow_names).to include("single_participatory_space_workflow")
      end

      context "when excluding a workflow" do
        it "excludes the specified workflow from options" do
          result = helper.delegate_workflow_options(exclude_workflow: :organization_welcome)
          workflow_names = result.map(&:last)
          expect(workflow_names).not_to include("organization_welcome")
          expect(workflow_names).to include("single_participatory_space_workflow")
        end
      end
    end
  end
end
