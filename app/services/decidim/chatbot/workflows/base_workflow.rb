# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class BaseWorkflow
        include Decidim::TranslatableAttributes
        include ActionView::Helpers::SanitizeHelper

        def initialize(params)
          @provider = params[:provider]
          @parent_workflow = params[:parent_workflow]
          @organization = params[:organization]
          @params = params
        end

        attr_reader :params, :provider, :organization, :parent_workflow, :delegated_workflow

        delegate :build_message, :consume_message, to: :adapter

        def start(force_welcome = false) # rubocop:disable Style/OptionalBooleanParameter
          byebug
          return { status: :ok }
          unless setting
            Rails.logger.error("Setting not found for organization #{organization.id} and provider #{provider}")
            return { status: :ok }
          end
          return delegated_workflow.start(force_welcome) if delegated_workflow

          mark_as_read if received_message.acknowledgeable?
          if received_message.user_text? || force_welcome
            process_user_input
          elsif received_message.actionable?
            process_action_input
          end
          consume_message
          { status: :ok }
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

        # Delegate the workflow to another workflow class
        def delegate_workflow(workflow_class)
          @delegated_workflow = workflow_class.new(params.merge(parent_workflow: self))
          @delegated_workflow.start(true)
        end

        def exit_delegation
          return unless parent_workflow

          parent_workflow.clear_delegated_workflow
          parent_workflow.start(true)
        end

        # Clear any delegated workflow
        def clear_delegated_workflow
          @delegated_workflow = nil
        end

        # Send acknowledgment message back to the user
        def mark_as_read
          adapter.mark_as_read!(received_message)
        end

        def setting
          @setting ||= Decidim::Chatbot::Setting.find_by(organization:, provider:)
        end

        def adapter
          @adapter ||= setting.adapter_manifest.adapter.new(params:)
        end

        def received_message
          @received_message ||= setting.messages.find_or_initialize_by(external_id: adapter.received_message.message_id) do |message|
            message.from = adapter.received_message.from
            message.to = adapter.received_message.to
            message.chat_id = adapter.received_message.chat_id
            message.user = setting.users.find_or_initialize_by(from: message.from)
            message.content = adapter.received_message.content
            message.save
            message
          end
        end

        def user
          @user ||= received_message&.user
        end
      end
    end
  end
end
