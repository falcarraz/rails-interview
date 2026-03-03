class TodoListItemBroadcastJob < ApplicationJob
  queue_as :default

  # en este caso no es realmente necesario usar un job, pero se hace para mostrar
  # como se puede usar un job para hacer broadcasting sin bloquear el response de la API
  def perform(todo_list_item)
    if todo_list_item.deleted_at?
      # Si el item fue soft-deleted, lo removemos del DOM en todos los clientes conectados
      todo_list_item.broadcast_remove_to(todo_list_item.todo_list)
    else
      todo_list_item.broadcast_replace_to(
        todo_list_item.todo_list,
        partial: "todo_lists/todo_list_item",
        locals: { item: todo_list_item }
      )
    end
  end
end
