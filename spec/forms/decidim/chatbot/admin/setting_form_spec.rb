# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe SettingForm do
    subject { form }

    let(:organization) { create(:organization) }
    let(:participatory_process) { create(:participatory_process, :published, organization:) }
    let(:component) { create(:component, :published, participatory_space: participatory_process) }

    let(:enabled) { false }
    let(:start_workflow) { "organization_welcome" }
    let(:participatory_space_gid) { nil }
    let(:component_id) { nil }
    let(:write_action) { nil }

    let(:params) do
      {
        enabled:,
        start_workflow:,
        participatory_space_gid:,
        component_id:,
        write_action:
      }
    end

    let(:form) do
      described_class.from_params(params).with_context(current_organization: organization)
    end

    describe "when enabled is false" do
      let(:enabled) { false }

      it { is_expected.to be_valid }

      context "without participatory space" do
        let(:participatory_space_gid) { nil }

        it { is_expected.to be_valid }
      end

      context "without component" do
        let(:component_id) { nil }

        it { is_expected.to be_valid }
      end
    end

    describe "when enabled is true" do
      let(:enabled) { true }
      let(:participatory_space_gid) { participatory_process.to_global_id.to_s }
      let(:component_id) { component.id }

      context "with valid space and component" do
        it { is_expected.to be_valid }
      end

      context "with write_action set" do
        let(:write_action) { "create_proposal" }

        it { is_expected.to be_valid }
      end

      context "without participatory space" do
        let(:participatory_space_gid) { nil }

        it { is_expected.not_to be_valid }

        it "adds error on participatory_space_gid" do
          subject.valid?
          expect(subject.errors[:participatory_space_gid]).not_to be_empty
        end
      end

      context "without component" do
        let(:component_id) { nil }

        it { is_expected.not_to be_valid }

        it "adds error on component_id" do
          subject.valid?
          expect(subject.errors[:component_id]).not_to be_empty
        end
      end

      context "with invalid participatory space gid" do
        let(:participatory_space_gid) { "invalid_gid" }

        it { is_expected.not_to be_valid }

        it "adds error on participatory_space_gid" do
          subject.valid?
          expect(subject.errors[:participatory_space_gid]).not_to be_empty
        end
      end

      context "when component does not belong to space" do
        let(:other_process) { create(:participatory_process, organization:) }
        let(:other_component) { create(:component, participatory_space: other_process) }
        let(:component_id) { other_component.id }

        it { is_expected.not_to be_valid }

        it "adds error on component_id" do
          subject.valid?
          expect(subject.errors[:component_id]).not_to be_empty
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

      it "maps participatory_space_gid correctly" do
        expect(form.participatory_space_gid).to eq(setting.participatory_space.to_global_id.to_s)
      end

      it "maps component_id correctly" do
        config = setting.config.with_indifferent_access
        expect(form.component_id).to eq(config[:component_id])
      end

      context "when setting is disabled" do
        let(:setting) { create(:chatbot_setting, organization:, config: { enabled: false }) }

        it "maps enabled as false" do
          expect(form.enabled).to be false
        end

        it "has nil participatory_space_gid" do
          expect(form.participatory_space_gid).to be_nil
        end
      end
    end

    describe "#participatory_space" do
      context "when participatory_space_gid is present" do
        let(:participatory_space_gid) { participatory_process.to_global_id.to_s }

        it "returns the participatory space" do
          expect(form.participatory_space).to eq(participatory_process)
        end
      end

      context "when participatory_space_gid is nil" do
        let(:participatory_space_gid) { nil }

        it "returns nil" do
          expect(form.participatory_space).to be_nil
        end
      end

      context "when participatory_space_gid is empty" do
        let(:participatory_space_gid) { "" }

        it "returns nil" do
          expect(form.participatory_space).to be_nil
        end
      end
    end

    describe "#enabled?" do
      context "when enabled is true" do
        let(:enabled) { true }

        it "returns true" do
          expect(form.enabled?).to be true
        end
      end

      context "when enabled is false" do
        let(:enabled) { false }

        it "returns false" do
          expect(form.enabled?).to be false
        end
      end

      context "when enabled is nil" do
        let(:enabled) { nil }

        it "returns false" do
          expect(form.enabled?).to be false
        end
      end
    end
  end
end
