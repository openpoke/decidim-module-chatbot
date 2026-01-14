# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class BaseWorkflow
        include Decidim::TranslatableAttributes
        include ActionView::Helpers::SanitizeHelper

        def initialize(adapter:, message:)
          @adapter = adapter
          @message = message
        end

        attr_reader :adapter, :message

        delegate :build_message, :received_message, :consume_message, to: :adapter
        delegate :setting, :sender, to: :message
        delegate :organization, to: :setting
        delegate :current_workflow, :parent_workflow, to: :sender

        def start(force_welcome = false) # rubocop:disable Style/OptionalBooleanParameter
          # return delegated_workflow.start(force_welcome) if delegated_workflow

          adapter.mark_as_read! if received_message.acknowledgeable?
          if received_message.user_text? || force_welcome
            process_user_input
          elsif received_message.actionable?
            process_action_input
          end
          # consume_message
        end

        protected

        # Messages started by the user are processed here (text based)
        def process_user_input
          raise NotImplementedError
        end

        # Actions started by the user are processed here (button clicks, etc.)
        def process_action_input
          raise NotImplementedError
        end

        # Delegate the workflow to another workflow class so subsequent messages are handled there
        def delegate_workflow(workflow_class)
          sender.update!(current_workflow_class: workflow_class.name, parent_workflow_class: self.class.name)
          sender.current_workflow.new(adapter:, message:).start(true)
        end

        def reset_workflows
          sender.update!(current_workflow_class: nil, parent_workflow_class: nil)
          adapter.send_message!(I18n.t("decidim.chatbot.messages.reset_workflows"))
        end
      end
    end
  end
end
