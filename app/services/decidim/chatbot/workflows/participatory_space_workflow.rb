# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class ParticipatorySpaceWorkflow < BaseWorkflow
        def process_user_input
          send
          parent_workflow&.clear_delegated_workflow
        end

        private

        def send
          message = build_message(
            to: received_message.from,
            type: :text,
            data: {
              body: "📬 Received:\n#{received_message.body}"
            }
          )

          adapter.send!(message)
        end
      end
    end
  end
end
