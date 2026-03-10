class ComponentSetsController < ApplicationController
  before_action :require_auth

  def update
    component_set = ComponentSet.find(params[:id])
    component_set.update!(component_set_params)
    render json: {
      id: component_set.id,
      name: component_set.name,
      is_root: component_set.is_root,
      slots: component_set.slots
    }
  end

  private

  def component_set_params
    params.require(:component_set).permit(:name)
  end
end
