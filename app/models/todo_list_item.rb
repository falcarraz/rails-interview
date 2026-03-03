class TodoListItem < ApplicationRecord
  belongs_to :todo_list

  validates :title, presence: true

  # Los items soft-deleted no aparecen en consultas normales.
  # El sync service usa TodoListItem.unscoped para procesar los tombstones.
  default_scope { where(deleted_at: nil) }
end