# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe SettingForm do
    subject { form }

    let(:organization) { create(:organization) }
    let(:participatory_process) { create(:participatory_process, :published, organization:) }
    let(:component) { create(:component, :published, participatory_space: participatory_process) }

    let(:enabled) { false }
    let(:start_workflow) { "single_participatory_space_workflow" }
    let(:config) { {} }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        config:
      }
    end

    let(:form) do
      described_class.from_params(params).with_context(current_organization: organization)
    end

    describe "when enabled is false" do
      let(:enabled) { false }

      it { is_expected.to be_valid }

      context "without config" do
        let(:config) { {} }

        it { is_expected.to be_valid }
      end
    end

    describe "when enabled is true" do
      let(:enabled) { true }
      let(:config) do
        {
          participatory_space_gid: participatory_process.to_global_id.to_s,
          component_id: component.id.to_s
        }
      end

      context "with valid space and component" do
        it { is_expected.to be_valid }
      end

      context "without participatory space GID" do
        let(:config) { { participatory_space_gid: "", component_id: component.id.to_s } }

        it { is_expected.not_to be_valid }

        it "adds error on config" do
          subject.valid?
          expect(subject.errors[:config]).not_to be_empty
        end
      end

      context "without component" do
        let(:config) { { participatory_space_gid: participatory_process.to_global_id.to_s, component_id: "" } }

        it { is_expected.not_to be_valid }

        it "adds error on config" do
          subject.valid?
          expect(subject.errors[:config]).not_to be_empty
        end
      end
    end

    describe "without start_workflow" do
      let(:start_workflow) { nil }

      it { is_expected.not_to be_valid }

      it "adds error on start_workflow" do
        subject.valid?
        expect(subject.errors[:start_workflow]).not_to be_empty
      end
    end

    describe "#map_model" do
      let(:setting) { create(:chatbot_setting, :enabled, organization:) }

      let(:form) do
        described_class.from_model(setting).with_context(current_organization: organization)
      end

      it "maps enabled correctly" do
        expect(form.enabled).to be true
      end

      it "maps start_workflow correctly" do
        expect(form.start_workflow).to eq(setting.start_workflow)
      end

      it "maps config with participatory_space_gid" do
        config = setting.config.with_indifferent_access
        expect(form.config[:participatory_space_gid]).to eq(config[:participatory_space_gid])
      end

      it "maps config with component_id" do
        config = setting.config.with_indifferent_access
        expect(form.config[:component_id]).to eq(config[:component_id])
      end

      context "when setting is disabled" do
        let(:setting) { create(:chatbot_setting, organization:, enabled: false) }

        it "maps enabled as false" do
          expect(form.enabled).to be false
        end
      end
    end

    describe "#available_workflows" do
      it "returns an array of workflow options" do
        workflows = form.available_workflows
        expect(workflows).to be_an(Array)
        expect(workflows.first).to be_an(Array)
        expect(workflows.first.length).to eq(2)
      end
    end

    describe "#workflow_manifest" do
      it "returns the manifest for the selected workflow" do
        expect(form.workflow_manifest).to be_present
        expect(form.workflow_manifest.name).to eq(:single_participatory_space_workflow)
      end
    end

    describe "#workflow_display_name" do
      it "returns the translated workflow title" do
        expect(form.workflow_display_name).to be_a(String)
      end
    end
  end
end
