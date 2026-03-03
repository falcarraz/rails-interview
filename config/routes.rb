Rails.application.routes.draw do
  namespace :api do
    resources :todo_lists, only: %i[index create update destroy], path: :todolists do
      resources :todo_list_items, only: %i[index show create update destroy], path: :items
    end

    post "sync", to: "sync#create"
  end

  resources :todo_lists, path: :todolists do
    resources :todo_list_items, only: %i[new create edit update destroy], path: :items
  end
end
