class TodoListsController < ApplicationController
  ITEMS_PER_PAGE = 50

  # GET /todolists
  def index
    @todo_lists = TodoList.left_joins(:todo_list_items)
                          .select("todo_lists.*, COUNT(todo_list_items.id) AS items_count")
                          .group("todo_lists.id")

    respond_to :html
  end

  # GET /todolists/:id
  def show
    @todo_list = TodoList.find(params[:id])
    @items = @todo_list.todo_list_items
                       .order(:id)
                       .limit(ITEMS_PER_PAGE)

    if params[:after].present?
      @items = @items.where("id > ?", params[:after])
      render partial: "items_page",
             locals: { items: @items, todo_list: @todo_list, cursor: params[:after] }
    else
      respond_to :html
    end
  end

  # GET /todolists/new
  def new
    @todo_list = TodoList.new

    respond_to :html
  end
end
