# frozen_string_literal: true

module Decidim
  module Chatbot
    class User < ApplicationRecord
      belongs_to :setting, class_name: "Decidim::Chatbot::Setting"
      belongs_to :decidim_user, class_name: "Decidim::User", optional: true
    end
  end
end
