# frozen_string_literal: true

class CreateDecidimChatbotMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_chatbot_messages do |t|
      t.references :decidim_chatbot_setting, null: false, foreign_key: { to_table: :decidim_chatbot_settings }, index: true
      t.references :decidim_chatbot_user, null: false, foreign_key: { to_table: :decidim_chatbot_users }, index: true
      t.string :provider, null: false
      t.string :chat_id, null: false, index: true # unique per chat thread
      t.string :external_id, null: false # unique per message from provider
      t.string :from, null: false
      t.string :to, null: false
      t.jsonb :content, null: false, default: {}
      t.datetime :read_at, null: true
      t.timestamps

      t.index [:provider, :external_id], unique: true, name: "index_decidim_chatbot_messages_on_provider_and_external_id"
    end
  end
end
