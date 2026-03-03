class TodoListItemBroadcastJob < ApplicationJob
  queue_as :default

  def perform(todo_list_item)
    todo_list_item.broadcast_replace_to(
      todo_list_item.todo_list,
      partial: "todo_lists/todo_list_item",
      locals: { item: todo_list_item }
    )
  end
end
