module Api
  class TodoListsController < ApplicationController
    protect_from_forgery with: :null_session
    # GET /api/todolists
    def index
      @todo_lists = TodoList.all

      respond_to :json
    end

    def create
      @todo_list = TodoList.create!(todo_list_params)

      render :json => @todo_list, :status => :created
    end

    def update
      @todo_list = TodoList.find(params[:id])
      @todo_list.update!(todo_list_params)

      render :json => @todo_list
    end

    def destroy
      @todo_list = TodoList.find(params[:id])
      @todo_list.destroy

      head :no_content
    end

    private 
    def todo_list_params
      params.require(:todo_list).permit(:name)
    end
  end
end
