# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot
  describe ApplicationHelper do
    let(:organization) { create(:organization) }
    let!(:participatory_process) { create(:participatory_process, organization:, title: { en: "My Process" }) }
    let!(:proposal_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals") }

    before do
      allow(helper).to receive(:current_organization).and_return(organization)
    end

    describe "#participatory_space_select" do
      let(:config) { {} }

      it "renders a select element" do
        result = helper.participatory_space_select(config, organization)
        expect(result).to include("select")
        expect(result).to include("setting[config][participatory_space_gid]")
      end

      it "includes participatory spaces in options" do
        result = helper.participatory_space_select(config, organization)
        expect(result).to include("My Process")
      end

      it "includes data attributes for stimulus" do
        result = helper.participatory_space_select(config, organization)
        expect(result).to include("chatbot-settings#loadComponents")
        expect(result).to include("spaceSelect")
      end

      context "when config has a saved space" do
        let(:config) { { participatory_space_gid: participatory_process.to_gid.to_s } }

        it "selects the saved space" do
          result = helper.participatory_space_select(config, organization)
          expect(result).to include("selected")
        end
      end

      context "when config is empty" do
        it "selects the first space by default" do
          result = helper.participatory_space_select(config, organization)
          expect(result).to include("selected")
        end
      end
    end

    describe "#component_select" do
      let(:config) { { participatory_space_gid: participatory_process.to_gid.to_s } }

      it "renders a select element" do
        result = helper.component_select(config, organization)
        expect(result).to include("select")
        expect(result).to include("setting[config][component_id]")
      end

      it "includes components in options" do
        result = helper.component_select(config, organization)
        expect(result).to include(proposal_component.id.to_s)
      end

      it "includes data attributes for stimulus" do
        result = helper.component_select(config, organization)
        expect(result).to include("componentSelect")
        expect(result).to include("componentsWrapper")
      end

      context "when no space in config but organization has spaces" do
        it "uses first space from organization and shows component select" do
          result = helper.component_select({}, organization)
          expect(result).not_to include("display:none")
          expect(result).to include(proposal_component.id.to_s)
        end
      end

      context "when config has a saved component" do
        let(:config) do
          {
            participatory_space_gid: participatory_process.to_gid.to_s,
            component_id: proposal_component.id.to_s
          }
        end

        it "selects the saved component" do
          result = helper.component_select(config, organization)
          expect(result).to include("selected")
        end
      end
    end

    describe "#delegate_workflow_select" do
      let(:config) { {} }

      it "renders a select element" do
        result = helper.delegate_workflow_select(config)
        expect(result).to include("select")
        expect(result).to include("setting[config][delegate_workflow]")
      end

      it "includes data attributes" do
        result = helper.delegate_workflow_select(config)
        expect(result).to include("setting_config_delegate_workflow")
      end

      context "when excluding a workflow" do
        it "excludes the specified workflow from options" do
          result = helper.delegate_workflow_select(config, exclude_workflow: :organization_welcome)
          expect(result).not_to include("organization_welcome")
        end
      end

      context "when config has a saved workflow" do
        let(:config) { { delegate_workflow: "single_participatory_space_workflow" } }

        it "selects the saved workflow" do
          result = helper.delegate_workflow_select(config)
          expect(result).to include("selected")
        end
      end
    end
  end
end
