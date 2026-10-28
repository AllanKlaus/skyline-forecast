Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  namespace :api do
    namespace :v1 do
      get "forecasts", to: "forecasts#show"
    end
  end
end
