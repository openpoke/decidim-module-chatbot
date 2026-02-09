# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class CommentsWorkflow < BaseWorkflow
        def process_user_input
          send_message!("todo: process user input for comments workflow for proposal #{proposal.id}")
        end

        private

        def proposal
          @proposal ||= Decidim::Proposals::Proposal.find_by(id: options[:proposal_id])
        end
      end
    end
  end
end
