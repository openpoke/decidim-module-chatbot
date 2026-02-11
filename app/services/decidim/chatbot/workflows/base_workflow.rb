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

        delegate :send_message!, :build_message, :received_message, to: :adapter
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

        def mark_as_read
          adapter.mark_as_read! if received_message.acknowledgeable?
          message.mark_as_read! if message
        end

        def mark_as_responding
          adapter.mark_as_responding! if received_message.acknowledgeable?
        end

        # Delegate the workflow to another workflow class so subsequent messages are handled there
        # Pushes the new workflow onto the stack, preserving the current workflow history
        # To replace the entire stack instead, call sender.clear_workflow_stack first
        def delegate_workflow(workflow_class, conf = {})
          sender.push_to_workflow_stack!(workflow_class, conf)
          sender.current_workflow.new(adapter:, message:, **conf).start(true)
        end

        def reset_workflows
          sender.clear_workflow_stack!
          send_message!(I18n.t(Chatbot.reset_workflows_message, default: Chatbot.reset_workflows_message)) if Chatbot.reset_workflows_message.present?
        end

        def exit_workflow
          # Pop current workflow from stack
          sender.pop_from_workflow_stack!

          # If stack is empty, reset everything
          reset_workflows if sender.workflow_stack.empty?
          # If stack has workflows, next message will be handled by the new current workflow (stack.last)
        end

        # Helper to access the workflow configuration, which is a combination of the setting's config and the options passed when delegating the workflow
        # The options passed when delegating the workflow take precedence over the setting's config, allowing to override specific values for specific users or flows.
        def config
          @config ||= (setting.config || {}).with_indifferent_access.merge(options)
        end

        def current_page
          config[:page].to_i.positive? ? config[:page].to_i : 1
        end

        def per_page
          10
        end

        # TODO: Propose deterministic random ordering in Decidim::Randomable for stable pagination.
        def order_randomly(scope, seed)
          connection = scope.klass.connection
          quoted_seed = connection.quote(seed)

          scope.order(
            Arel.sql("md5(#{scope.table_name}.#{scope.primary_key}::text || #{quoted_seed})")
          )
        end

        # Prepare a message to be sent to the user, applying necessary sanitization and formatting.
        # TODO: limit message length depending on the provider's requirements, for example WhatsApp has a 4096 character limit for text messages.
        # Accepts a string or hash with languages
        def sanitize_text(text)
          strip_tags(translated_attribute(text))
        end

        def image_url(path)
          ActionController::Base.helpers.image_pack_url(path, host: "https://#{organization.host}")
        end
      end
    end
  end
end
