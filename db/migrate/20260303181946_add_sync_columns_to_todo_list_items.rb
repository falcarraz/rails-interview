class AddSyncColumnsToTodoListItems < ActiveRecord::Migration[7.0]
  def change
    add_column :todo_list_items, :external_id, :string
    add_column :todo_list_items, :synced_at, :datetime
    add_index :todo_list_items, :external_id, unique: true
  end
end
