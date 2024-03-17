Rails.application.routes.draw do
  resources :custom_message_settings, only: [] do
    get  :edit,             on: :collection
    get  :default_messages, on: :collection
    post :update,           on: :collection
    post :toggle_enabled,   on: :collection
  end

  post 'projects/:project_id/settings/message_customize', controller: 'custom_message_settings', action: 'update', as: 'projects_custom_message_settings'
end