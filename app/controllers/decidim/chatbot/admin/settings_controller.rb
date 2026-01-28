# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      class SettingsController < ApplicationController
        helper_method :setting_for_provider

        def index
          enforce_permission_to :update, :organization, organization: current_organization
          @provider_manifests = Decidim::Chatbot.providers_registry.manifests
        end

        def edit
          enforce_permission_to :update, :organization, organization: current_organization
          @form = form(SettingForm).from_model(current_setting)
          @workflow_manifest = @form.workflow_manifest
        end

        def update
          enforce_permission_to :update, :organization, organization: current_organization
          @form = form(SettingForm).from_params(params)

          UpdateSetting.call(@form, current_setting) do
            on(:ok) do
              flash[:notice] = I18n.t("settings.update.success", scope: "decidim.chatbot.admin")
              redirect_to settings_path
            end

            on(:invalid) do
              @workflow_manifest = @form.workflow_manifest
              flash.now[:alert] = I18n.t("settings.update.error", scope: "decidim.chatbot.admin")
              render :edit, status: :unprocessable_entity
            end
          end
        end

        def components
          enforce_permission_to :update, :organization, organization: current_organization
          space = find_participatory_space
          return render json: [] unless space

          render json: space.components.published.where(manifest_name: "proposals").map { |c|
            { id: c.id, name: translated_attribute(c.name), manifest_name: c.manifest_name }
          }
        end

        def workflow_fields
          enforce_permission_to :update, :organization, organization: current_organization
          manifest = Decidim::Chatbot.start_workflows_registry.find(params[:workflow].to_sym)
          @form = form(SettingForm).from_model(current_setting)

          render partial: "workflow_config",
                 locals: {
                   workflow_manifest: manifest,
                   workflow_display_name: manifest&.title.to_s,
                   form: nil,
                   setting_form: @form,
                   config: @form.config
                 },
                 layout: false
        end

        def toggle
          enforce_permission_to :update, :organization, organization: current_organization
          new_enabled = current_setting.toggle_enabled!

          respond_to do |format|
            format.html do
              flash[:notice] = toggle_flash_message(new_enabled)
              redirect_to settings_path
            end
            format.json do
              render json: { enabled: new_enabled }
            end
          end
        end

        private

        def find_participatory_space
          return nil if params[:space_gid].blank?

          GlobalID::Locator.locate(params[:space_gid])
        rescue ActiveRecord::RecordNotFound
          nil
        end

        def toggle_flash_message(enabled)
          key = enabled ? "settings.toggle.enabled" : "settings.toggle.disabled"
          I18n.t(key, scope: "decidim.chatbot.admin")
        end

        def current_setting
          @current_setting ||= Decidim::Chatbot::Setting.find_or_initialize_by(
            organization: current_organization,
            provider: params[:id] || "whatsapp"
          ) do |setting|
            setting.start_workflow = "single_participatory_space_workflow"
          end
        end

        def setting_for_provider(provider)
          settings_by_provider[provider.to_s]
        end

        def settings_by_provider
          @settings_by_provider ||= Decidim::Chatbot::Setting.where(organization: current_organization).index_by(&:provider)
        end
      end
    end
  end
end
