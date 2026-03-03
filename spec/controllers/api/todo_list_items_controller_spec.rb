require 'rails_helper'

describe Api::TodoListItemsController do
  render_views

  let!(:todo_list) { TodoList.create!(name: 'My List') }

  describe 'GET index' do
    let!(:item) { todo_list.todo_list_items.create!(title: 'Buy milk', description: 'From the store', completed: false) }

    context 'when format is JSON' do
      it 'returns a success code' do
        get :index, params: { todo_list_id: todo_list.id }, format: :json

        expect(response.status).to eq(200)
      end

      it 'includes todo list item records' do
        get :index, params: { todo_list_id: todo_list.id }, format: :json

        items = JSON.parse(response.body)

        aggregate_failures 'includes the expected fields' do
          expect(items.count).to eq(1)
          expect(items[0].keys).to match_array(%w[id title description completed])
          expect(items[0]['id']).to eq(item.id)
          expect(items[0]['title']).to eq('Buy milk')
        end
      end
    end

    context 'when the todo list does not exist' do
      it 'returns 404 not found' do
        get :index, params: { todo_list_id: 0 }, format: :json

        expect(response.status).to eq(404)
      end
    end
  end

  describe 'GET show' do
    let!(:item) { todo_list.todo_list_items.create!(title: 'Buy milk') }

    it 'returns a success code' do
      get :show, params: { todo_list_id: todo_list.id, id: item.id }, format: :json

      expect(response.status).to eq(200)
    end

    it 'returns the item' do
      get :show, params: { todo_list_id: todo_list.id, id: item.id }, format: :json

      result = JSON.parse(response.body)

      aggregate_failures 'includes the expected fields' do
        expect(result.keys).to match_array(%w[id title description completed])
        expect(result['id']).to eq(item.id)
        expect(result['title']).to eq('Buy milk')
      end
    end

    context 'when the item does not exist' do
      it 'returns 404 not found' do
        get :show, params: { todo_list_id: todo_list.id, id: 0 }, format: :json

        expect(response.status).to eq(404)
      end
    end
  end

  describe 'POST create' do
    context 'with valid params' do
      it 'returns 201 created' do
        post :create, params: { todo_list_id: todo_list.id, todo_list_item: { title: 'New item' } }, format: :json

        expect(response.status).to eq(201)
      end

      it 'creates a new item' do
        expect {
          post :create, params: { todo_list_id: todo_list.id, todo_list_item: { title: 'New item' } }, format: :json
        }.to change(TodoListItem, :count).by(1)
      end

      it 'returns the expected fields' do
        post :create, params: { todo_list_id: todo_list.id, todo_list_item: { title: 'New item', description: 'Details' } }, format: :json

        result = JSON.parse(response.body)

        expect(result.keys).to match_array(%w[id title description completed])
      end
    end

    context 'with invalid params' do
      it 'returns 422 unprocessable entity' do
        post :create, params: { todo_list_id: todo_list.id, todo_list_item: { title: '' } }, format: :json

        expect(response.status).to eq(422)
      end
    end

    context 'without required params' do
      it 'returns 400 bad request' do
        post :create, params: { todo_list_id: todo_list.id }, format: :json

        expect(response.status).to eq(400)
      end
    end
  end

  describe 'PATCH update' do
    let!(:item) { todo_list.todo_list_items.create!(title: 'Original Title') }

    context 'with valid params' do
      it 'returns 200 ok' do
        patch :update, params: { todo_list_id: todo_list.id, id: item.id, todo_list_item: { title: 'Updated Title' } }, format: :json

        expect(response.status).to eq(200)
      end

      it 'updates the item' do
        patch :update, params: { todo_list_id: todo_list.id, id: item.id, todo_list_item: { title: 'Updated Title' } }, format: :json

        expect(item.reload.title).to eq('Updated Title')
      end

      it 'updates the completed status' do
        patch :update, params: { todo_list_id: todo_list.id, id: item.id, todo_list_item: { completed: true } }, format: :json

        expect(item.reload.completed).to be true
      end
    end

    context 'with invalid params' do
      before do
        allow_any_instance_of(TodoListItem).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(TodoListItem.new))
      end

      it 'returns 422 unprocessable entity' do
        patch :update, params: { todo_list_id: todo_list.id, id: item.id, todo_list_item: { title: '' } }, format: :json

        expect(response.status).to eq(422)
      end
    end

    context 'when the item does not exist' do
      it 'returns 404 not found' do
        patch :update, params: { todo_list_id: todo_list.id, id: 0, todo_list_item: { title: 'Test' } }, format: :json

        expect(response.status).to eq(404)
      end
    end
  end

  describe 'DELETE destroy' do
    let!(:item) { todo_list.todo_list_items.create!(title: 'To Be Deleted') }

    context 'when the item exists' do
      it 'returns 204 no content' do
        delete :destroy, params: { todo_list_id: todo_list.id, id: item.id }, format: :json

        expect(response.status).to eq(204)
      end

      it 'soft-deletes the item (sets deleted_at, keeps the record for sync tombstone)' do
        delete :destroy, params: { todo_list_id: todo_list.id, id: item.id }, format: :json

        # El registro sigue existiendo pero con deleted_at seteado
        deleted = TodoListItem.unscoped.find(item.id)
        expect(deleted.deleted_at).not_to be_nil
      end

      it 'hides the item from normal queries' do
        delete :destroy, params: { todo_list_id: todo_list.id, id: item.id }, format: :json

        expect(todo_list.todo_list_items.find_by(id: item.id)).to be_nil
      end
    end

    context 'when the item does not exist' do
      it 'returns 404 not found' do
        delete :destroy, params: { todo_list_id: todo_list.id, id: 0 }, format: :json

        expect(response.status).to eq(404)
      end
    end
  end
end
