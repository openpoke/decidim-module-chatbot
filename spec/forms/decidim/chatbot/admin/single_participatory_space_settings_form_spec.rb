# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe SingleParticipatorySpaceSettingsForm do
    subject { form }

    let(:organization) { create(:organization) }
    let!(:participatory_process) { create(:participatory_process, :published, organization:, title: { en: "My Process" }) }
    let!(:proposal_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals") }
    let!(:meeting_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "meetings") }

    let(:enabled) { false }
    let(:start_workflow) { "single_participatory_space_workflow" }
    let(:participatory_space_gid) { participatory_process.to_global_id.to_s }
    let(:component_id) { proposal_component.id.to_s }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        participatory_space_gid:,
        component_id:
      }
    end

    let(:form) do
      described_class.from_params(params).with_context(current_organization: organization)
    end

    describe "validations" do
      context "when disabled" do
        let(:enabled) { false }
        let(:participatory_space_gid) { nil }
        let(:component_id) { nil }

        it { is_expected.to be_valid }
      end

      context "when enabled" do
        let(:enabled) { true }

        context "with valid space and component" do
          it { is_expected.to be_valid }
        end

        context "without participatory_space_gid" do
          let(:participatory_space_gid) { "" }

          it { is_expected.not_to be_valid }

          it "adds error on participatory_space_gid" do
            subject.valid?
            expect(subject.errors[:participatory_space_gid]).not_to be_empty
          end
        end

        context "without component_id" do
          let(:component_id) { "" }

          it { is_expected.not_to be_valid }

          it "adds error on component_id" do
            subject.valid?
            expect(subject.errors[:component_id]).not_to be_empty
          end
        end
      end
    end

    describe "#map_model" do
      let(:setting) { create(:chatbot_setting, :enabled, organization:) }

      let(:form) do
        described_class.from_model(setting).with_context(current_organization: organization)
      end

      it "maps participatory_space_gid from config" do
        expect(form.participatory_space_gid).to eq(setting.config["participatory_space_gid"])
      end

      it "maps component_id from config" do
        expect(form.component_id).to eq(setting.config["component_id"].to_s)
      end
    end

    describe "#workflow_config" do
      it "returns hash with participatory_space_gid and component_id" do
        config = form.workflow_config
        expect(config[:participatory_space_gid]).to eq(participatory_space_gid)
        expect(config[:component_id]).to eq(component_id)
      end

      context "with blank values" do
        let(:participatory_space_gid) { "" }
        let(:component_id) { "" }

        it "returns empty hash" do
          expect(form.workflow_config).to eq({})
        end
      end
    end

    describe "#participatory_space_options" do
      it "returns grouped participatory spaces" do
        result = form.participatory_space_options
        expect(result).to be_a(Hash)
        expect(result.keys).to include("Participatory processes")
      end

      it "includes the participatory process" do
        result = form.participatory_space_options
        process_options = result["Participatory processes"]
        expect(process_options.map(&:last)).to include(participatory_process.to_gid.to_s)
      end
    end

    describe "#component_options" do
      it "returns only proposal components for the selected space" do
        result = form.component_options
        expect(result.length).to eq(1)
        expect(result.first.last).to eq(proposal_component.id.to_s)
      end
    end

    describe "#components_for_space" do
      it "returns only proposal components" do
        result = form.components_for_space(participatory_process.to_gid.to_s)
        expect(result.length).to eq(1)
        expect(result.first.last).to eq(proposal_component.id.to_s)
      end

      it "returns empty array for blank space_gid" do
        expect(form.components_for_space("")).to eq([])
      end

      it "returns empty array for space from another organization" do
        other_org = create(:organization)
        other_process = create(:participatory_process, organization: other_org)
        expect(form.components_for_space(other_process.to_gid.to_s)).to eq([])
      end
    end

    describe "#components_json" do
      it "returns JSON with only proposal components grouped by space gid" do
        result = JSON.parse(form.components_json)
        components = result[participatory_process.to_gid.to_s]
        expect(components.length).to eq(1)
        expect(components.first["id"]).to eq(proposal_component.id.to_s)
      end
    end
  end
end
