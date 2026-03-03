Rails.application.routes.draw do
  scope :api do
    resources :images, :only => :index

    resources :tasks, :only => [:show, :update] do
      get :next, :on => :collection
    end

    resources :renders, :only => :show

    resources :component_libraries, :only => [:index, :create, :show, :update], :path => "component-libraries" do
      get :available, :on => :collection
      get :preview, :on => :member
      get :renderer, :on => :member
      post :sync, :on => :member
      get :components, :on => :member, :action => :components_list
    end

    resources :components, :only => [:update] do
      get :figma_json, :on => :member
      get :svg, :on => :member
      get :html_preview, :on => :member
      post :reimport, :on => :member
      get :visual_diff, :on => :member
      get :diff_image, :on => :member
      get "screenshots/:type", :on => :member, :action => :screenshot, :as => :screenshot
    end

    resources :component_sets, :only => [:update], :path => "component-sets" do
      get :figma_json, :on => :member, :action => :component_set_figma_json, :controller => :components
      get :svg, :on => :member, :action => :component_set_svg, :controller => :components
      post :reimport, :on => :member
    end

    resources :design_systems, :only => [:index, :create], :path => "design-systems" do
      get :renderer, :on => :member
    end

    resources :iterations, :only => [] do
      get :renderer, :on => :member
    end

    resources :designs, :only => [:show, :create, :index, :update, :destroy] do
      post :improve
      post "apply/:message_id", :action => :apply_director_comments
      post :duplicate, :on => :member
      get :export_image, :on => :member
      get :export_react, :on => :member
      get :export_figma, :on => :member
    end

    resources :custom_components, :only => [:create, :update, :destroy],
      :path => "custom-components", :controller => "custom_components"

    get "up" => "application#health_check", :as => :rails_health_check
  end

  # SPA fallback — serve index.html for non-API routes (client-side routing)
  get "*path", to: "application#spa_fallback", constraints: ->(req) { !req.path.start_with?("/api") && !req.path.include?(".") }
end
