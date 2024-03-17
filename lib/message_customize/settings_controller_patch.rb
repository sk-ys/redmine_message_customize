# frozen_string_literal: true

module MessageCustomize
  module SettingsControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethod)
      base.class_eval do
        alias_method :plugin_without_update_custom_message_settings, :plugin
        alias_method :plugin, :plugin_with_update_custom_message_settings
      end
    end

    module InstanceMethod
      def plugin_with_update_custom_message_settings
        if params[:id] != "redmine_message_customize" || !request.post?
          plugin_without_update_custom_message_settings
          return
        end

        plugin = Redmine::Plugin.find(params[:id])

        custom_message_settings = CustomMessageSetting.find_or_default
        settings = params[:settings]&.permit!&.to_h&.deep_symbolize_keys

        if settings.present?
          custom_message_settings.value = custom_message_settings.value.merge(settings)
          custom_message_settings.save

          flash[:notice] = l(:notice_successful_update)
        end

        redirect_to plugin_settings_path(plugin)
      end
    end
  end
end

SettingsController.include(MessageCustomize::SettingsControllerPatch)
