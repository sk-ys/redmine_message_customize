class CustomMessageSettingsController < ApplicationController
  layout 'admin'
  menu_item :custom_messages
  self.main_menu = false
  before_action :require_admin_if_global, only: [:update, :toggle_enabled]
  before_action :set_custom_message_setting, :set_lang
  before_action :find_project, only: [:edit, :update, :toggle_enabled]
  before_action :authorize_if_project, only: [:update, :toggle_enabled]
  require_sudo_mode :edit, :update, :toggle_enabled, :default_messages

  def edit
  end

  def default_messages
    @file_path = Rails.root.join('config', 'locales', "#{@lang}.yml")
  end

  def update
    if setting_params.key?(:custom_messages) || params[:tab] == 'normal'
      @setting.update_with_custom_messages(setting_params[:custom_messages].try(:to_unsafe_h).try(:to_hash) || {}, @lang, params[:project_id])
    elsif setting_params.key?(:custom_messages_yaml)
      @setting.update_with_custom_messages_yaml(setting_params[:custom_messages_yaml], params[:project_id])
    end

    if params[:project_id].present?
      flash[:notice] = l(:notice_successful_update) if @setting.errors.blank?
      redirect_to projects_custom_message_settings_path(tab: params[:tab], lang: @lang)
    else
      if @setting.errors.blank?
        flash[:notice] = l(:notice_successful_update)
        redirect_to edit_custom_message_settings_path(tab: params[:tab], lang: @lang)
      else
        render :edit
      end
    end

  # Catch an exception that occurs when the value field capacity is exceeded (ActiveRecord::ValueTooLong)
  rescue ActiveRecord::StatementInvalid
    render_error l(:error_value_too_long)
  end

  def toggle_enabled
    if @setting.toggle_enabled!(params[:project_id])
      flash[:notice] =
        @setting.enabled?(params[:project_id]) ? l(:notice_enabled_customize) : l(:notice_disabled_customize)
      if params[:project_id].present?
        redirect_to projects_custom_message_settings_path(tab: params[:tab], lang: @lang, project_id: params[:project_id])
      else
        redirect_to edit_custom_message_settings_path
      end
    else
      if params[:project_id].present?
        redirect_to projects_custom_message_settings_path(tab: params[:tab], lang: @lang, project_id: params[:project_id])
      else
        render :edit
      end
    end
  end

  private

  def set_custom_message_setting
    @setting = CustomMessageSetting.find_or_default
  end

  def setting_params
    params.fetch(:settings, {})
  end

  def set_lang
    @lang =
      MessageCustomize::Locale.find_language(
        params[:lang].presence || @setting.custom_messages.keys.first || current_user_language
      )
  end

  def find_project(project_id=params[:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    @project = nil
  end

  def require_admin_if_global
    require_admin if params[:project_id].blank?
  end

  def authorize_if_project
    if params[:project_id].present?
      authorize(
        ctrl = params[:controller],
        action = params[:action] == 'toggle_enabled' ? 'update' : params[:action]
        )
    end
  end
end
