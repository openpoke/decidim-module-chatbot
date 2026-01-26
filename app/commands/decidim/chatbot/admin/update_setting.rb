# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      class UpdateSetting < Decidim::Command
        def initialize(form, setting)
          @form = form
          @setting = setting
        end

        def call
          return broadcast(:invalid) if form.invalid?

          update_setting
          broadcast(:ok, setting)
        end

        private

        attr_reader :form, :setting

        def update_setting
          setting.update!(
            start_workflow: form.start_workflow,
            config: build_config
          )
        end

        def build_config
          {
            enabled: form.enabled,
            participatory_space_type: form.participatory_space&.class&.name,
            participatory_space_id: form.participatory_space&.id,
            component_id: form.component_id
          }
        end
      end
    end
  end
end
