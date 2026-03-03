class AddDefaultCompletedToTodoListItems < ActiveRecord::Migration[7.0]
  def change
    change_column_default :todo_list_items, :completed, from: nil, to: false
    TodoListItem.where(completed: nil).update_all(completed: false)
  end
end
