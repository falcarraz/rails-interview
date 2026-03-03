require 'rails_helper'

describe Api::TodoListsController do
  render_views

  describe 'GET index' do
    let!(:todo_list) { TodoList.create(name: 'Setup RoR project') }

    context 'when format is HTML' do
      it 'raises a routing error' do
        expect {
          get :index
        }.to raise_error(ActionController::RoutingError, 'Not supported format')
      end
    end

    context 'when format is JSON' do
      it 'returns a success code' do
        get :index, format: :json

        expect(response.status).to eq(200)
      end

      it 'includes todo list records' do
        get :index, format: :json

        todo_lists = JSON.parse(response.body)

        aggregate_failures 'includes the id and name' do
          expect(todo_lists.count).to eq(1)
          expect(todo_lists[0].keys).to match_array(['id', 'name'])
          expect(todo_lists[0]['id']).to eq(todo_list.id)
          expect(todo_lists[0]['name']).to eq(todo_list.name)
        end
      end
    end
  end

  describe 'POST create' do
    context 'with valid params' do
      it 'returns 201 created' do
        post :create, params: { todo_list: { name: 'My List' } }, format: :json

        expect(response.status).to eq(201)
      end

      it 'creates a new todo list' do
        expect {
          post :create, params: { todo_list: { name: 'My List' } }, format: :json
        }.to change(TodoList, :count).by(1)
      end
    end

    context 'with invalid params' do
      before do
        allow_any_instance_of(TodoList).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(TodoList.new))
      end

      it 'returns 422 unprocessable entity' do
        post :create, params: { todo_list: { name: '' } }, format: :json

        expect(response.status).to eq(422)
      end
    end
  end

  describe 'PATCH update' do
    let!(:todo_list) { TodoList.create(name: 'Original Name') }

    context 'with valid params' do
      it 'returns 200 ok' do
        patch :update, params: { id: todo_list.id, todo_list: { name: 'Updated Name' } }, format: :json

        expect(response.status).to eq(200)
      end

      it 'updates the todo list' do
        patch :update, params: { id: todo_list.id, todo_list: { name: 'Updated Name' } }, format: :json

        expect(todo_list.reload.name).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      before do
        allow_any_instance_of(TodoList).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(TodoList.new))
      end

      it 'returns 422 unprocessable entity' do
        patch :update, params: { id: todo_list.id, todo_list: { name: '' } }, format: :json

        expect(response.status).to eq(422)
      end
    end
  end

  describe 'DELETE destroy' do
    let!(:todo_list) { TodoList.create(name: 'To Be Deleted') }

    context 'when the record exists' do
      it 'returns 204 no content' do
        delete :destroy, params: { id: todo_list.id }, format: :json

        expect(response.status).to eq(204)
      end

      it 'deletes the todo list' do
        expect {
          delete :destroy, params: { id: todo_list.id }, format: :json
        }.to change(TodoList, :count).by(-1)
      end
    end

    context 'when the record does not exist' do
      it 'returns 404 not found' do
        delete :destroy, params: { id: 0 }, format: :json

        expect(response.status).to eq(404)
      end
    end
  end
end
