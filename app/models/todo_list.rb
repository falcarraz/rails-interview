class TodoList < ApplicationRecord
  has_many :todo_list_items, dependent: :destroy

  validates :name, presence: true
end
