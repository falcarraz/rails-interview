class AddDeletedAtToTodoListItems < ActiveRecord::Migration[7.0]
  def change
    add_column :todo_list_items, :deleted_at, :datetime
    add_index :todo_list_items, :deleted_at
  end
end
