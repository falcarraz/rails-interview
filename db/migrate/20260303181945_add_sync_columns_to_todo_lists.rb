class AddSyncColumnsToTodoLists < ActiveRecord::Migration[7.0]
  def change
    add_column :todo_lists, :external_id, :string
    add_column :todo_lists, :synced_at, :datetime
    add_index :todo_lists, :external_id, unique: true
  end
end
