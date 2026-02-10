# frozen_string_literal: true

module Decidim
  module Chatbot
    class SendMessageJob < ApplicationJob
      queue_as :default

      def perform(message_body, adapter, params)
        instance = adapter.constantize.new(params: params)
        instance.send!(message_body)
      end
    end
  end
end
