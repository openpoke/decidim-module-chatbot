# frozen_string_literal: true

require "spec_helper"

module Decidim::Chatbot::Admin
  describe SettingsController do
    routes { Decidim::Chatbot::AdminEngine.routes }

    let(:organization) { create(:organization) }
    let(:current_user) { create(:user, :admin, :confirmed, organization:) }
    let(:participatory_process) { create(:participatory_process, :published, organization:) }
    let(:component) { create(:component, :published, participatory_space: participatory_process) }

    before do
      request.env["decidim.current_organization"] = organization
      sign_in current_user, scope: :user
    end

    describe "GET #index" do
      it "returns http success" do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it "renders the index template" do
        get :index
        expect(response).to render_template(:index)
      end

      context "when not authenticated" do
        before { sign_out current_user }

        it "redirects" do
          get :index
          expect(response).to have_http_status(:redirect)
        end
      end

      context "when user is not admin" do
        let(:current_user) { create(:user, :confirmed, organization:) }

        it "denies access" do
          get :index
          expect(response).to have_http_status(:redirect)
        end
      end
    end

    describe "GET #edit" do
      it "returns http success" do
        get :edit, params: { id: "whatsapp" }
        expect(response).to have_http_status(:ok)
      end

      it "renders the edit template" do
        get :edit, params: { id: "whatsapp" }
        expect(response).to render_template(:edit)
      end

      it "assigns the form" do
        get :edit, params: { id: "whatsapp" }
        expect(assigns(:form)).to be_a(SettingForm)
      end

      context "with existing setting" do
        let!(:setting) { create(:chatbot_setting, :enabled, organization:) }

        it "loads the existing setting into form" do
          get :edit, params: { id: "whatsapp" }
          form = assigns(:form)
          expect(form.enabled).to be true
        end
      end

      context "without existing setting" do
        it "initializes a new setting" do
          get :edit, params: { id: "whatsapp" }
          form = assigns(:form)
          expect(form.start_workflow).to eq("single_participatory_space_workflow")
        end
      end
    end

    describe "PATCH #update" do
      let(:valid_params) do
        {
          id: "whatsapp",
          setting: {
            enabled: true,
            start_workflow: "single_participatory_space_workflow",
            config: {
              participatory_space_gid: participatory_process.to_global_id.to_s,
              component_id: component.id.to_s
            }
          }
        }
      end

      let(:invalid_params) do
        {
          id: "whatsapp",
          setting: {
            enabled: true,
            start_workflow: "single_participatory_space_workflow",
            config: {
              participatory_space_gid: "",
              component_id: ""
            }
          }
        }
      end

      context "with valid params" do
        it "redirects to settings path" do
          patch :update, params: valid_params
          expect(response).to redirect_to(settings_path)
        end

        it "sets a flash notice" do
          patch :update, params: valid_params
          expect(flash[:notice]).to be_present
        end

        it "creates or updates the setting" do
          expect do
            patch :update, params: valid_params
          end.to change(Decidim::Chatbot::Setting, :count).by(1)
        end

        it "enables the chatbot" do
          patch :update, params: valid_params
          setting = Decidim::Chatbot::Setting.find_by(organization:, provider: "whatsapp")
          expect(setting.enabled?).to be true
        end

        context "with existing setting" do
          let!(:setting) { create(:chatbot_setting, organization:, provider: "whatsapp") }

          it "updates the existing setting" do
            expect do
              patch :update, params: valid_params
            end.not_to change(Decidim::Chatbot::Setting, :count)

            setting.reload
            expect(setting.enabled?).to be true
          end
        end
      end

      context "with invalid params" do
        it "renders the edit template" do
          patch :update, params: invalid_params
          expect(response).to render_template(:edit)
        end

        it "sets a flash alert" do
          patch :update, params: invalid_params
          expect(flash[:alert]).to be_present
        end

        it "does not create a setting" do
          expect do
            patch :update, params: invalid_params
          end.not_to change(Decidim::Chatbot::Setting, :count)
        end
      end

      context "when disabling chatbot" do
        let!(:setting) { create(:chatbot_setting, :enabled, organization:) }

        let(:disable_params) do
          {
            id: "whatsapp",
            setting: {
              enabled: false,
              start_workflow: "organization_welcome",
              config: {}
            }
          }
        end

        it "redirects to settings path" do
          patch :update, params: disable_params
          expect(response).to redirect_to(settings_path)
        end

        it "disables the chatbot" do
          patch :update, params: disable_params
          setting.reload
          expect(setting.enabled?).to be false
        end
      end
    end

    describe "GET #components" do
      let!(:proposal_component) do
        create(:component, :published, participatory_space: participatory_process, manifest_name: "proposals")
      end

      it "returns json response" do
        get :components, params: { id: "whatsapp", space_gid: participatory_process.to_global_id.to_s }
        expect(response.content_type).to include("application/json")
      end

      it "returns components for the space" do
        get :components, params: { id: "whatsapp", space_gid: participatory_process.to_global_id.to_s }
        json_response = response.parsed_body
        expect(json_response).to be_an(Array)
        expect(json_response.map { |c| c["id"] }).to include(proposal_component.id)
      end

      context "with invalid space_gid" do
        it "returns empty array" do
          get :components, params: { id: "whatsapp", space_gid: "invalid" }
          expect(response.parsed_body).to eq([])
        end
      end

      context "without space_gid" do
        it "returns empty array" do
          get :components, params: { id: "whatsapp" }
          expect(response.parsed_body).to eq([])
        end
      end
    end

    describe "GET #workflow_fields" do
      context "with a configurable workflow" do
        it "returns the workflow partial" do
          get :workflow_fields, params: { id: "whatsapp", workflow: "single_participatory_space_workflow" }
          expect(response).to have_http_status(:ok)
        end
      end

      context "with a non-configurable workflow" do
        before do
          manifest = instance_double(Decidim::Chatbot::StartWorkflowsManifest, configurable?: false, title: "Non Configurable")
          allow(Decidim::Chatbot.start_workflows_registry).to receive(:find).and_return(manifest)
        end

        it "returns empty response" do
          get :workflow_fields, params: { id: "whatsapp", workflow: "non_configurable" }
          expect(response).to have_http_status(:ok)
          expect(response.body.strip).to eq("")
        end
      end
    end

    describe "PATCH #toggle" do
      let!(:setting) { create(:chatbot_setting, organization:, enabled: false) }

      it "toggles the enabled status" do
        patch :toggle, params: { id: "whatsapp" }
        setting.reload
        expect(setting.enabled?).to be true
      end

      it "redirects to settings path" do
        patch :toggle, params: { id: "whatsapp" }
        expect(response).to redirect_to(settings_path)
      end

      it "sets a flash notice" do
        patch :toggle, params: { id: "whatsapp" }
        expect(flash[:notice]).to be_present
      end

      context "with JSON format" do
        it "returns JSON response" do
          patch :toggle, params: { id: "whatsapp" }, format: :json
          expect(response.content_type).to include("application/json")
          expect(response.parsed_body["enabled"]).to be true
        end
      end
    end
  end
end
