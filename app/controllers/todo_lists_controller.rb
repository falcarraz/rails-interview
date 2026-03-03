class TodoListsController < ApplicationController
  ITEMS_PER_PAGE = 50

  before_action :set_todo_list, only: %i[show edit update destroy]

  # GET /todolists
  def index
    @todo_lists = TodoList.left_joins(:todo_list_items)
                          .select("todo_lists.*, COUNT(todo_list_items.id) AS items_count")
                          .group("todo_lists.id")

    respond_to :html
  end

  # GET /todolists/:id
  def show
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

  # POST /todolists
  def create
    @todo_list = TodoList.new(todo_list_params)

    if @todo_list.save
      redirect_to @todo_list, notice: "List created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /todolists/:id/edit
  def edit
    respond_to :html
  end

  # PATCH /todolists/:id
  def update
    if @todo_list.update(todo_list_params)
      redirect_to @todo_list, notice: "List updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /todolists/:id
  def destroy
    @todo_list.destroy
    redirect_to todo_lists_path, notice: "List deleted."
  end

  private

  def set_todo_list
    @todo_list = TodoList.find(params[:id])
  end

  def todo_list_params
    params.require(:todo_list).permit(:name)
  end
end
