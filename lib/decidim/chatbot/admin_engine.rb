# frozen_string_literal: true

module Decidim
  module Chatbot
    # This is the engine that runs on the admin interface of `Chatbot`.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::Chatbot::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        resources :settings, only: [:index, :edit, :update] do
          member do
            get :components
            patch :toggle
          end
        end
        root to: "settings#index"
      end

      initializer "decidim_chatbot_admin.menu" do
        Decidim.menu :admin_menu do |menu|
          menu.add_item :chatbot,
                        I18n.t("menu.chatbot", scope: "decidim.chatbot.admin"),
                        decidim_admin_chatbot.settings_path,
                        icon_name: "chat-1-line",
                        position: 7.5,
                        active: is_active_link?(decidim_admin_chatbot.settings_path, :inclusive),
                        if: allowed_to?(:update, :organization, organization: current_organization)
        end
      end

      def load_seed
        nil
      end
    end
  end
end
