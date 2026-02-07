# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class OrganizationWelcomeWorkflow < BaseWorkflow
        def process_user_input
          send_welcome
        end

        private

        def send_welcome
          message = build_message(
            to: received_message.from,
            type: :text,
            data: {
              body: body,
              preview_url: true
            }
          )

          adapter.send!(message)
        end

        def body
          "*#{translated_attribute(organization.name)}*\n\n#{welcome_body_text}\n\n#{Decidim::Core::Engine.routes.url_helpers.root_url(host: organization.host)}"
        end

        def welcome_body_text
          config[:custom_text].presence || decidim_sanitize(translated_attribute(organization.description), strip_tags: true)
        end

        def config
          @config ||= (setting.config || {}).with_indifferent_access
        end
      end
    end
  end
end
