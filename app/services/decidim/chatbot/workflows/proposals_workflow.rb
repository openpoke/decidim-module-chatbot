# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ProposalsWorkflow < BaseWorkflow
        def process_user_input
          send_welcome
        end

        private

        def send_welcome
          message = build_message(
            to: received_message.from,
            type: :text,
            data: {
              body: body
            }
          )

          adapter.send!(message)
        end

        def body
          announcement = sanitize(component&.settings&.announcement)
          "*#{sanitize(component.name)}*\n\n#{announcement}"
        end

        def component
          @component ||= Decidim::Component.find_by(id: config[:component_id])
        end
      end
    end
  end
end
