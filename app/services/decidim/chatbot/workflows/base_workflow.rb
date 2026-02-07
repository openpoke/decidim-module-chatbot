# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class BaseWorkflow
        include Decidim::TranslatableAttributes
        include Decidim::SanitizeHelper

        def initialize(adapter:, message:, **options)
          @adapter = adapter
          @message = message
          @options = options
        end

        attr_reader :adapter, :message, :options

        delegate :build_message, :received_message, to: :adapter
        delegate :setting, :sender, to: :message
        delegate :organization, to: :setting
        delegate :current_workflow, :parent_workflow, to: :sender

        def start(force_welcome = false) # rubocop:disable Style/OptionalBooleanParameter
          mark_as_read
          if received_message.user_text? || force_welcome
            process_user_input
          elsif received_message.actionable?
            process_action_input
          end
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

        # Prepare a message to be sent to the user, applying necessary sanitization and formatting.
        # TODO: limit message length depending on the provider's requirements, for example WhatsApp has a 4096 character limit for text messages.
        # Accepts a string or hash with languages
        def sanitize(text)
          strip_tags(translated_attribute(text))
        end

        def mark_as_read
          adapter.mark_as_read! if received_message.acknowledgeable?
          message.mark_as_read! if message
        end

        # Delegate the workflow to another workflow class so subsequent messages are handled there
        def delegate_workflow(workflow_class, conf = {})
          sender.set_workflows!(
            workflow_class.name,
            self.class.name,
            {
              current_workflow_options: conf,
              parent_workflow_options: options
            }
          )
          sender.current_workflow.new(adapter:, message:, **conf).start(true)
        end

        def reset_workflows
          sender.set_workflows!(nil)
          adapter.send_message!(I18n.t(Chatbot.reset_workflows_message, default: Chatbot.reset_workflows_message)) if Chatbot.reset_workflows_message.present?
        end

        def exit_workflow
          if parent_workflow.nil?
            reset_workflows
          else
            # Go back to parent workflow
            sender.set_workflows!(
              parent_workflow,
              nil,
              current_workflow_options: sender.parent_workflow_options,
              parent_workflow_options: nil
            )
            parent_workflow_instance = parent_workflow.constantize.new(adapter:, message:, **sender.parent_workflow_options)
            parent_workflow_instance.start(true)
          end
        end

        # Helper to access the workflow configuration, which is a combination of the setting's config and the options passed when delegating the workflow
        # The options passed when delegating the workflow take precedence over the setting's config, allowing to override specific values for specific users or flows.
        def config
          @config ||= (setting.config || {}).with_indifferent_access.merge(options)
        end
      end
    end
  end
end
