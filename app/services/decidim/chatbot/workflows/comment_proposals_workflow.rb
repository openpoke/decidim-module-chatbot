# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class CommentProposalsWorkflow < BaseWorkflow
        def show_menu
          send!
        end

        private

        def send!
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
