# frozen_string_literal: true

module Decidim
  module Chatbot
    class Message < ApplicationRecord
      belongs_to :setting, class_name: "Decidim::Chatbot::Setting"
      belongs_to :sender, class_name: "Decidim::Chatbot::Sender", optional: true
    end
  end
end
