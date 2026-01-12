# frozen_string_literal: true

module Decidim
  module Chatbot
    class Message < ApplicationRecord
      attr_accessor :adapter

      def text
        content.dig("body", "text")
      end
    end
  end
end
