require 'rails_helper'

RSpec.describe TodoList, type: :model do
  describe 'validations' do
    it 'is valid with a name' do
      todo_list = TodoList.new(name: 'My List')

      expect(todo_list).to be_valid
    end

    it 'is invalid without a name' do
      todo_list = TodoList.new(name: nil)

      expect(todo_list).not_to be_valid
    end
  end

  describe 'associations' do
    it 'has many todo list items' do
      todo_list = TodoList.create!(name: 'My List')
      todo_list.todo_list_items.create!(title: 'Item 1')
      todo_list.todo_list_items.create!(title: 'Item 2')

      expect(todo_list.todo_list_items.count).to eq(2)
    end

    it 'destroys associated items when destroyed' do
      todo_list = TodoList.create!(name: 'My List')
      todo_list.todo_list_items.create!(title: 'Item 1')

      expect { todo_list.destroy }.to change(TodoListItem, :count).by(-1)
    end
  end
end
