# frozen_string_literal: true

require "decidim/components/namer"
require "decidim/core/test/factories"

FactoryBot.define do
  factory :chatbot_setting, class: "Decidim::Chatbot::Setting" do
    organization
    provider { "whatsapp" }
    start_workflow { "organization_welcome" }
    config { {} }
  end

  factory :chatbot_sender, class: "Decidim::Chatbot::Sender" do
    setting { association :chatbot_setting }
    decidim_user { nil }
    sequence(:from) { |n| "3468517332#{n}" }
    name { "Test User" }
    metadata { {} }
    current_workflow_class { nil }
    parent_workflow_class { nil }

    trait :with_user do
      decidim_user { association :user, organization: setting.organization }
    end

    trait :with_workflow do
      current_workflow_class { "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow" }
    end

    trait :with_parent_workflow do
      current_workflow_class { "Decidim::Chatbot::Workflows::ParticipatorySpaceWorkflow" }
      parent_workflow_class { "Decidim::Chatbot::Workflows::OrganizationWelcomeWorkflow" }
    end
  end

  factory :chatbot_message, class: "Decidim::Chatbot::Message" do
    setting { association :chatbot_setting }
    sender { association :chatbot_sender, setting: }
    chat_id { "818813757760148" }
    sequence(:message_id) { |n| "wamid.HBgLMzQ2ODUxNzMzMjYVAgASGBYzRUIwMThFMjdEQzMwMkQ0REZCQzA#{n}" }
    message_type { "text" }
    content { { "body" => "Hello, this is a test message" } }
    read_at { nil }

    trait :read do
      read_at { Time.current }
    end

    trait :interactive do
      message_type { "interactive" }
      content { { "button_reply" => { "id" => "start", "title" => "Start" } } }
    end
  end
end
