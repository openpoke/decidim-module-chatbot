# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class OrganizationWelcomeWorkflow < BaseWorkflow
        def process_action_input
          process_user_input
        end

        def process_user_input
          send_message!(body:, preview_url: true)
        end

        private

        def body
          "*#{translated_attribute(organization.name)}*\n\n#{welcome_body_text}\n\n#{resource_url(organization)}"
        end

        def welcome_body_text
          config[:custom_text].presence || decidim_sanitize(translated_attribute(organization.description), strip_tags: true)
        end
      end
    end
  end
end
