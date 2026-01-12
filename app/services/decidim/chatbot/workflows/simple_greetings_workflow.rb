# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class SimpleGreetingsWorkflow < BaseWorkflow
        def process!
          if received_message.from_user?
            mark_as_read!
            send!
          end
          { status: :ok }
        end

        private

        # Send acknowledgment message back to the user
        def mark_as_read!
          adapter.mark_as_read!(received_message)
        end

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
