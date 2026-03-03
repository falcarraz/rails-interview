class TodoListItemsController < ApplicationController
  before_action :set_todo_list
  before_action :set_item, only: %i[edit update destroy]

  # GET /todolists/:todo_list_id/items/new
  def new
    @item = @todo_list.todo_list_items.build
  end

  # POST /todolists/:todo_list_id/items
  def create
    @item = @todo_list.todo_list_items.build(item_params)

    if @item.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @todo_list, notice: "Item added." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /todolists/:todo_list_id/items/:id/edit
  def edit
  end

  # PATCH /todolists/:todo_list_id/items/:id
  def update
    if @item.update(item_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @todo_list, notice: "Item updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /todolists/:todo_list_id/items/:id
  def destroy
    @item.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @todo_list, notice: "Item deleted." }
    end
  end

  private

  def set_todo_list
    @todo_list = TodoList.find(params[:todo_list_id])
  end

  def set_item
    @item = @todo_list.todo_list_items.find(params[:id])
  end

  def item_params
    params.require(:todo_list_item).permit(:title, :description, :completed)
  end
end
