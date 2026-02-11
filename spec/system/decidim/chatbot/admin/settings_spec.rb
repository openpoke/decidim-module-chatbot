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
      visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "organization_welcome")

      expect(page).to have_select("setting_start_workflow")
    end

    context "when organization_welcome workflow is selected" do
      it "renders welcome workflow form with custom_text" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "organization_welcome")

        expect(page).to have_field("setting_custom_text")
      end
    end

    context "when single_participatory_space is selected" do
      it "renders participatory space workflow form with space select" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "single_participatory_space")

        expect(page).to have_select("setting_participatory_space_gid")
        expect(page).to have_css("#setting_component_id", visible: :all)
      end
    end

    context "when switching workflows" do
      it "changes the configuration form" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "organization_welcome")
        expect(page).to have_field("setting_custom_text")

        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "single_participatory_space")
        expect(page).to have_select("setting_participatory_space_gid")
        expect(page).to have_no_field("setting_custom_text")
      end
    end
  end

  describe "saving settings" do
    context "with organization_welcome workflow" do
      it "saves custom_text" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "organization_welcome")

        fill_in "setting_custom_text", with: "Welcome to our chatbot!"
        check "setting_enabled"

        click_on "Save"

        expect(page).to have_content("Chatbot settings saved successfully")

        setting = Decidim::Chatbot::Setting.find_by(organization:, provider: "whatsapp")
        expect(setting.start_workflow).to eq("organization_welcome")
        expect(setting.config["custom_text"]).to eq("Welcome to our chatbot!")
        expect(setting.enabled?).to be true
      end
    end

    context "with single_participatory_space" do
      it "saves participatory space and component" do
        visit decidim_admin_chatbot.edit_setting_path(id: "whatsapp", workflow: "single_participatory_space")

        # Select participatory space
        find_by_id("setting_participatory_space_gid").select(participatory_process.title["en"])

        # Manually trigger change event for JavaScript
        page.execute_script("document.getElementById('setting_participatory_space_gid').dispatchEvent(new Event('change'))")

        # Wait for JavaScript to show component selector
        expect(page).to have_css("#components_wrapper:not([style*='display: none'])", wait: 2)

        find_by_id("setting_component_id").select(translated(proposal_component.name))
        check "setting_enabled"

        click_on "Save"

        expect(page).to have_content("Chatbot settings saved successfully")

        setting = Decidim::Chatbot::Setting.find_by(organization:, provider: "whatsapp")
        expect(setting.start_workflow).to eq("single_participatory_space")
        expect(setting.config["participatory_space_gid"]).to eq(participatory_process.to_global_id.to_s)
        expect(setting.config["component_id"]).to eq(proposal_component.id.to_s)
        expect(setting.enabled?).to be true
      end
    end
  end
end
