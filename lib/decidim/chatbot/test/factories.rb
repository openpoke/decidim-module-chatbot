# frozen_string_literal: true

require "decidim/components/namer"
require "decidim/core/test/factories"

FactoryBot.define do
  factory :chatbot_setting, class: "Decidim::Chatbot::Setting" do
    organization
    provider { "whatsapp" }
    start_workflow { "organization_welcome" }
  end
end
