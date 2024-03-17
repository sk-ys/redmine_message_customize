require_dependency 'project'

module MessageCustomize
  module ProjectPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :destroy_without_remove_custom_messages, :destroy
        alias_method :destroy, :destroy_with_remove_custom_messages
      end
    end

    module InstanceMethods
      def destroy_with_remove_custom_messages
        destroy_without_remove_custom_messages

        custom_message_setting = CustomMessageSetting.find_or_default
        custom_message_setting.remove_project(self.identifier)
      end
    end
  end
end

Project.send(:include, MessageCustomize::ProjectPatch)