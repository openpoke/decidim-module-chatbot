# frozen_string_literal: true

class CreateDecidimChatbotMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :decidim_chatbot_messages do |t|
      t.references :setting, null: false, foreign_key: { to_table: :decidim_chatbot_settings }, index: true
      t.references :sender, null: true, foreign_key: { to_table: :decidim_chatbot_senders }, index: true
      t.string :chat_id, null: false, index: true # unique per chat thread
      t.string :message_id, null: false
      t.string :message_type, null: false
      t.jsonb :content, null: false, default: {}
      t.datetime :read_at, null: true
      t.timestamps

      t.index [:setting_id, :message_id], unique: true, name: "index_decidim_chatbot_messages_on_setting_and_message_id"
    end
  end
end
