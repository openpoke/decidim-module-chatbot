# frozen_string_literal: true

class CreateDecidimChatbotUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_chatbot_users do |t|
      t.references :decidim_chatbot_setting, null: false, foreign_key: { to_table: :decidim_chatbot_settings }, index: true
      t.references :decidim_user, null: true, foreign_key: { to_table: :decidim_users }, index: true
      t.string :provider, null: false
      t.string :from, null: false
      t.string :current_workflow, null: true
      t.timestamps

      t.index [:decidim_chatbot_setting_id, :provider, :from], unique: true, name: "index_decidim_chatbot_users_on_setting_and_provider_and_from"
    end
  end
end
