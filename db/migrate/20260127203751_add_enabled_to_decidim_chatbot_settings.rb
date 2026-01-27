# frozen_string_literal: true

class AddEnabledToDecidimChatbotSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :decidim_chatbot_settings, :enabled, :boolean, default: false, null: false
  end
end
