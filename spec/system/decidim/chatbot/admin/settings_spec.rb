# frozen_string_literal: true

require "spec_helper"

describe "Admin manages chatbot settings" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization:) }
  let!(:participatory_process) { create(:participatory_process, :published, organization:) }
  let!(:proposal_component) { create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals") }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  describe "editing settings" do
    it "shows workflow selector" do
      visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp")

      expect(page).to have_select("setting_start_workflow")
    end

    context "when organization_welcome workflow is selected" do
      it "renders welcome workflow form with custom_text and delegate_workflow" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp")

        select "Organization Welcome", from: "setting_start_workflow"

        expect(page).to have_field("setting_config_custom_text")
        expect(page).to have_select("setting_config_delegate_workflow")
      end
    end

    context "when single_participatory_space_workflow is selected" do
      it "renders participatory space workflow form with space select" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp")

        select "Single Participatory Space", from: "setting_start_workflow"

        expect(page).to have_select("setting_config_participatory_space_gid")
        # Component select is hidden until space is selected
        expect(page).to have_css("#setting_config_component_id", visible: :all)
      end
    end

    context "when switching workflows" do
      it "changes the configuration form" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp")

        select "Organization Welcome", from: "setting_start_workflow"
        expect(page).to have_field("setting_config_custom_text")
        expect(page).to have_no_select("setting_config_participatory_space_gid")

        select "Single Participatory Space", from: "setting_start_workflow"
        expect(page).to have_select("setting_config_participatory_space_gid")
        expect(page).to have_no_field("setting_config_custom_text")
      end
    end
  end

  describe "saving settings" do
    context "with organization_welcome workflow" do
      it "saves custom_text and delegate_workflow" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp")

        select "Organization Welcome", from: "setting_start_workflow"
        fill_in "setting_config_custom_text", with: "Welcome to our chatbot!"
        check "setting_enabled"

        click_on "Save"

        expect(page).to have_content("Chatbot settings saved successfully")

        setting = Decidim::Chatbot::Setting.find_by(organization:, provider: "whatsapp")
        expect(setting.start_workflow).to eq("organization_welcome")
        expect(setting.config["custom_text"]).to eq("Welcome to our chatbot!")
        expect(setting.enabled?).to be true
      end
    end

    context "with single_participatory_space_workflow" do
      it "saves participatory space and component" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp")

        select "Single Participatory Space", from: "setting_start_workflow"
        select participatory_process.title["en"], from: "setting_config_participatory_space_gid"
        select translated(proposal_component.name), from: "setting_config_component_id"
        check "setting_enabled"

        click_on "Save"

        expect(page).to have_content("Chatbot settings saved successfully")

        setting = Decidim::Chatbot::Setting.find_by(organization:, provider: "whatsapp")
        expect(setting.start_workflow).to eq("single_participatory_space_workflow")
        expect(setting.config["participatory_space_gid"]).to eq(participatory_process.to_global_id.to_s)
        expect(setting.config["component_id"]).to eq(proposal_component.id.to_s)
        expect(setting.enabled?).to be true
      end
    end
  end
end
