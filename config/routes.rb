Rails.application.routes.draw do
  namespace :admin do
    resources :lizenzo_imports, :only => [:index, :new, :create]
  end
end
