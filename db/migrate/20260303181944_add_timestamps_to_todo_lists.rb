class AddTimestampsToTodoLists < ActiveRecord::Migration[7.0]
  def change
    add_timestamps :todo_lists, null: true
    now = Time.current
    TodoList.update_all(created_at: now, updated_at: now)
    change_column_null :todo_lists, :created_at, false
    change_column_null :todo_lists, :updated_at, false
  end
end
