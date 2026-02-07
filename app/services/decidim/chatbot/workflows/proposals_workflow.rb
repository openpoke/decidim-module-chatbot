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
          adapter.send_message!("hi #{sender.name}, here are the proposals")
        end
      end
    end
  end
end
