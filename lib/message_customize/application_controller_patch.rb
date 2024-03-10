# frozen_string_literal: true

module MessageCustomize
  module ApplicationControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethod)
      base.class_eval do
        before_action :reload_customize_messages
      end
    end

    module InstanceMethod
      def reload_customize_messages
        custom_message_setting = CustomMessageSetting.find_or_default

        project_id = params["project_id"]
        if project_id.nil?
          if params["controller"] == "projects" && params["id"].present?
            project_id = Project.find(params["id"]).name.downcase
          elsif params["controller"] == "issues" && params["id"].present?
            project_id = Issue.find(params["id"]).project.name.downcase
          end
        end

        # TODO:
        # return if custom_message_setting.latest_messages_applied?(current_user_language, project_id)

        MessageCustomize::Locale.reload!([current_user_language], project_id)
      end

      private

      def current_user_language
        User.current.language.presence || Setting.default_language
      end
    end
  end
end

ApplicationController.include(MessageCustomize::ApplicationControllerPatch)
