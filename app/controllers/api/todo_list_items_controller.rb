module Api
  class TodoListItemsController < ApplicationController
    protect_from_forgery with: :null_session

    before_action :set_todo_list
    before_action :set_todo_list_item, only: %i[show update destroy]

    # GET /api/todolists/:todo_list_id/items
    def index
      @todo_list_items = @todo_list.todo_list_items

      respond_to :json
    end

    # GET /api/todolists/:todo_list_id/items/:id
    def show
      render json: item_json(@todo_list_item)
    end

    # POST /api/todolists/:todo_list_id/items
    def create
      @todo_list_item = @todo_list.todo_list_items.create!(todo_list_item_params)

      render json: item_json(@todo_list_item), status: :created
    end

    # PATCH /api/todolists/:todo_list_id/items/:id
    def update
      @todo_list_item.update!(todo_list_item_params)

      TodoListItemBroadcastJob.perform_later(@todo_list_item)

      render json: item_json(@todo_list_item)
    end

    # DELETE /api/todolists/:todo_list_id/items/:id
    # Soft delete: marcamos deleted_at en lugar de borrar el registro.
    # El sync service detecta estos tombstones y propaga el DELETE al remoto.
    def destroy
      @todo_list_item.update!(deleted_at: Time.current)
      TodoListItemBroadcastJob.perform_later(@todo_list_item)

      head :no_content
    end

    private

    def set_todo_list
      @todo_list = TodoList.find(params[:todo_list_id])
    end

    def set_todo_list_item
      @todo_list_item = @todo_list.todo_list_items.find(params[:id])
    end

    def todo_list_item_params
      params.require(:todo_list_item).permit(:title, :description, :completed)
    end

    def item_json(item)
      item.as_json(only: %i[id title description completed])
    end
  end
end
