require 'rails_helper'

RSpec.describe TodoListItem, type: :model do
  let(:todo_list) { TodoList.create!(name: 'My List') }

  describe 'validations' do
    it 'is valid with a title' do
      item = TodoListItem.new(title: 'Buy milk', todo_list: todo_list)

      expect(item).to be_valid
    end

    it 'is invalid without a title' do
      item = TodoListItem.new(title: nil, todo_list: todo_list)

      expect(item).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a todo list' do
      item = TodoListItem.create!(title: 'Buy milk', todo_list: todo_list)

      expect(item.todo_list).to eq(todo_list)
    end
  end
end
