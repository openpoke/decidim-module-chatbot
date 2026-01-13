# frozen_string_literal: true

module Decidim
  module Chatbot
    module Workflows
      class BaseWorkflow
        include Decidim::TranslatableAttributes
        include ActionView::Helpers::SanitizeHelper

        def initialize(params)
          @provider = params[:provider]
          @adapter_manifest = Decidim::Chatbot.providers_registry.find(provider.to_sym)
          @adapter = adapter_manifest.adapter.new(params:)
          @params = params
          @organization = params[:organization]
        end

        attr_reader :params, :adapter, :provider, :adapter_manifest, :organization

        delegate :build_message, :received_message, :consume_message, to: :adapter

        def start
          mark_as_read if received_message.acknowledgeable?
          if received_message.user_text?
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

        # Send acknowledgment message back to the user
        def mark_as_read
          adapter.mark_as_read!(received_message)
        end
      end
    end
  end
end
