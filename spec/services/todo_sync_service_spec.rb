require 'rails_helper'

RSpec.describe TodoSyncService do
  include ActiveSupport::Testing::TimeHelpers

  let(:client) { instance_double(ExternalTodoClient) }
  let(:service) { described_class.new(client: client) }
  let(:now) { Time.zone.parse("2026-03-03 12:00:00") }

  before { travel_to(now) }
  after { travel_back }

  describe '#call' do
    context 'when a local list has no external_id (new local list)' do
      it 'pushes the list to the external API' do
        local_list = TodoList.create!(name: "Groceries")
        item = local_list.todo_list_items.create!(title: "Milk", description: "2%")

        allow(client).to receive(:fetch_all_lists).and_return([])
        allow(client).to receive(:create_list).and_return({
          "id" => "ext-1",
          "name" => "Groceries",
          "items" => [{ "id" => "ext-item-1", "source_id" => item.id.to_s }]
        })

        result = service.call

        expect(client).to have_received(:create_list).with(
          source_id: local_list.id,
          name: "Groceries",
          items: [{ source_id: item.id.to_s, description: "Milk: 2%", completed: false }]
        )
        expect(local_list.reload.external_id).to eq("ext-1")
        expect(item.reload.external_id).to eq("ext-item-1")
        expect(result[:success]).to include(hash_including(action: :pushed_new))
      end
    end

    context 'when a remote list has no local match (new remote list)' do
      it 'creates the list locally' do
        allow(client).to receive(:fetch_all_lists).and_return([
          {
            "id" => "ext-1",
            "source_id" => nil,
            "name" => "Work Tasks",
            "items" => [
              { "id" => "ext-item-1", "source_id" => nil, "description" => "Deploy: to production", "completed" => false }
            ],
            "updated_at" => now.iso8601
          }
        ])

        result = service.call

        local_list = TodoList.find_by(external_id: "ext-1")
        expect(local_list).to be_present
        expect(local_list.name).to eq("Work Tasks")
        expect(local_list.todo_list_items.count).to eq(1)

        item = local_list.todo_list_items.first
        expect(item.title).to eq("Deploy")
        expect(item.description).to eq("to production")
        expect(item.external_id).to eq("ext-item-1")
        expect(result[:success]).to include(hash_including(action: :pulled_new))
      end
    end

    context 'when only the local list changed since last sync' do
      it 'pushes the name change to the external API' do
        local_list = TodoList.create!(name: "Updated Name", external_id: "ext-1", synced_at: 1.hour.ago)

        allow(client).to receive(:fetch_all_lists).and_return([
          { "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "Old Name", "items" => [], "updated_at" => 2.hours.ago.iso8601 }
        ])
        allow(client).to receive(:update_list).and_return({ "id" => "ext-1", "name" => "Updated Name" })

        result = service.call

        expect(client).to have_received(:update_list).with("ext-1", name: "Updated Name")
        expect(result[:success]).to include(hash_including(action: :synced))
      end
    end

    context 'when only the remote list changed since last sync' do
      it 'pulls the remote name into the local list' do
        local_list = TodoList.create!(name: "Old Name", external_id: "ext-1")
        # Simulate the record being in sync: both updated_at and synced_at in the past
        local_list.update_columns(updated_at: 30.minutes.ago, synced_at: 30.minutes.ago)

        allow(client).to receive(:fetch_all_lists).and_return([
          { "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "Remote Name", "items" => [], "updated_at" => 5.minutes.ago.iso8601 }
        ])

        service.call

        expect(local_list.reload.name).to eq("Remote Name")
      end
    end

    context 'when both sides changed (conflict)' do
      it 'remote wins — pulls the remote version' do
        local_list = TodoList.create!(name: "Local Edit", external_id: "ext-1", synced_at: 1.hour.ago)

        allow(client).to receive(:fetch_all_lists).and_return([
          { "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "Remote Edit", "items" => [], "updated_at" => 5.minutes.ago.iso8601 }
        ])

        service.call

        expect(local_list.reload.name).to eq("Remote Edit")
      end
    end

    context 'when a synced list was deleted remotely' do
      it 'destroys the local list' do
        local_list = TodoList.create!(name: "Doomed", external_id: "ext-gone", synced_at: 1.hour.ago)

        allow(client).to receive(:fetch_all_lists).and_return([])

        result = service.call

        expect(TodoList.find_by(id: local_list.id)).to be_nil
        expect(result[:success]).to include(hash_including(action: :deleted_locally))
      end
    end

    context 'when a synced item was soft-deleted locally' do
      it 'deletes it from the external API and hard-deletes the tombstone' do
        local_list = TodoList.create!(name: "List", external_id: "ext-1")
        local_list.update_columns(updated_at: 30.minutes.ago, synced_at: 30.minutes.ago)
        item = local_list.todo_list_items.create!(title: "Gone", external_id: "ext-item-1")
        # Simula soft delete: marcamos deleted_at manualmente (bypasa el default_scope)
        TodoListItem.unscoped.find(item.id).update_column(:deleted_at, Time.current)

        allow(client).to receive(:fetch_all_lists).and_return([
          { "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List",
            "items" => [{ "id" => "ext-item-1", "source_id" => item.id.to_s, "description" => "Gone", "completed" => false, "updated_at" => 2.hours.ago.iso8601 }],
            "updated_at" => 2.hours.ago.iso8601 }
        ])
        allow(client).to receive(:delete_item)

        service.call

        expect(client).to have_received(:delete_item).with("ext-1", "ext-item-1")
        # El tombstone fue hard-deleted después de propagar el DELETE al remoto
        expect(TodoListItem.unscoped.find_by(id: item.id)).to be_nil
      end

      it 'hard-deletes the tombstone even when the remote item is already gone (404)' do
        local_list = TodoList.create!(name: "List", external_id: "ext-1")
        local_list.update_columns(updated_at: 30.minutes.ago, synced_at: 30.minutes.ago)
        item = local_list.todo_list_items.create!(title: "Gone", external_id: "ext-item-already-gone")
        TodoListItem.unscoped.find(item.id).update_column(:deleted_at, Time.current)

        allow(client).to receive(:fetch_all_lists).and_return([
          { "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List", "items" => [], "updated_at" => 2.hours.ago.iso8601 }
        ])
        allow(client).to receive(:delete_item).and_raise(ExternalTodoClient::NotFoundError)

        service.call

        expect(TodoListItem.unscoped.find_by(id: item.id)).to be_nil
      end
    end

    context 'when a synced item was deleted remotely' do
      it 'destroys the local item' do
        local_list = TodoList.create!(name: "List", external_id: "ext-1", synced_at: 1.hour.ago)
        local_list.update_column(:synced_at, 1.second.from_now)
        item = local_list.todo_list_items.create!(title: "Gone", external_id: "ext-item-gone", synced_at: 1.hour.ago)

        allow(client).to receive(:fetch_all_lists).and_return([
          { "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List", "items" => [], "updated_at" => 2.hours.ago.iso8601 }
        ])

        service.call

        expect(TodoListItem.find_by(id: item.id)).to be_nil
      end
    end

    context 'when there are new local items on a synced list' do
      let(:local_list) do
        l = TodoList.create!(name: "List", external_id: "ext-1")
        l.update_columns(updated_at: 30.minutes.ago, synced_at: 30.minutes.ago)
        l
      end
      let!(:new_item) { local_list.todo_list_items.create!(title: "New Item") }
      let(:remote_stub) do
        [{ "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List", "items" => [], "updated_at" => 2.hours.ago.iso8601 }]
      end

      it 'rebuilds the external list to include the new items' do
        allow(client).to receive(:fetch_all_lists).and_return(remote_stub)
        allow(client).to receive(:delete_list)
        allow(client).to receive(:create_list).and_return({
          "id" => "ext-2",
          "name" => "List",
          "items" => [{ "id" => "ext-item-new", "source_id" => new_item.id.to_s }]
        })

        service.call

        expect(client).to have_received(:delete_list).with("ext-1")
        expect(client).to have_received(:create_list)
        expect(local_list.reload.external_id).to eq("ext-2")
        expect(new_item.reload.external_id).to eq("ext-item-new")
      end

      it 'clears external_id locally when recreate fails after deletion' do
        allow(client).to receive(:fetch_all_lists).and_return(remote_stub)
        allow(client).to receive(:delete_list)
        allow(client).to receive(:create_list).and_raise(ExternalTodoClient::ServerError, "503")

        result = service.call

        # Failure is isolated — does not propagate as an unhandled exception
        expect(result[:failed]).not_to be_empty
        # external_id cleared so the next sync re-pushes the list cleanly
        # instead of detecting it as "deleted remotely" and destroying local data
        expect(local_list.reload.external_id).to be_nil
      end
    end

    context 'when one list fails during sync' do
      it 'continues syncing other lists' do
        failing_list = TodoList.create!(name: "Failing", external_id: "ext-fail", synced_at: 1.hour.ago)
        ok_list = TodoList.create!(name: "OK List")

        allow(client).to receive(:fetch_all_lists).and_return([
          # Remote name differs from local AND remote_updated < synced_at so only local changed → push path → raises
          { "id" => "ext-fail", "source_id" => failing_list.id.to_s, "name" => "Failing (remote)", "items" => [], "updated_at" => 2.hours.ago.iso8601 }
        ])
        allow(client).to receive(:update_list).and_raise(ExternalTodoClient::ServerError, "500 boom")
        allow(client).to receive(:create_list).and_return({ "id" => "ext-ok", "name" => "OK List", "items" => [] })

        result = service.call

        expect(result[:failed].size).to eq(1)
        expect(result[:failed].first[:error]).to include("500 boom")
        expect(result[:success]).to include(hash_including(action: :pushed_new))
      end
    end

    context 'item-level sync' do
      it 'pushes locally changed items to external' do
        local_list = TodoList.create!(name: "List", external_id: "ext-1", synced_at: 1.hour.ago)
        local_list.update_column(:synced_at, 1.second.from_now)
        item = local_list.todo_list_items.create!(
          title: "Updated Task", description: "details", completed: true,
          external_id: "ext-item-1", synced_at: 1.hour.ago
        )

        allow(client).to receive(:fetch_all_lists).and_return([
          {
            "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List",
            "items" => [
              { "id" => "ext-item-1", "source_id" => item.id.to_s, "description" => "Old Task", "completed" => false, "updated_at" => 2.hours.ago.iso8601 }
            ],
            "updated_at" => 2.hours.ago.iso8601
          }
        ])
        allow(client).to receive(:update_item).and_return({})

        service.call

        expect(client).to have_received(:update_item).with("ext-1", "ext-item-1", description: "Updated Task: details", completed: true)
      end

      it 'pulls remotely changed items into local' do
        local_list = TodoList.create!(name: "List", external_id: "ext-1")
        local_list.update_columns(updated_at: 30.minutes.ago, synced_at: 30.minutes.ago)
        item = local_list.todo_list_items.create!(
          title: "Old", description: "", completed: false,
          external_id: "ext-item-1"
        )
        # Simulate item being in sync: updated_at == synced_at in the past
        item.update_columns(updated_at: 30.minutes.ago, synced_at: 30.minutes.ago)

        allow(client).to receive(:fetch_all_lists).and_return([
          {
            "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List",
            "items" => [
              { "id" => "ext-item-1", "source_id" => item.id.to_s, "description" => "New Title: new desc", "completed" => true, "updated_at" => 1.minute.ago.iso8601 }
            ],
            "updated_at" => 2.hours.ago.iso8601
          }
        ])

        service.call

        item.reload
        expect(item.title).to eq("New Title")
        expect(item.description).to eq("new desc")
        expect(item.completed).to be true
      end

      it 'pulls new remote items into local' do
        local_list = TodoList.create!(name: "List", external_id: "ext-1", synced_at: 1.second.from_now)
        local_list.update_column(:synced_at, 1.second.from_now)

        allow(client).to receive(:fetch_all_lists).and_return([
          {
            "id" => "ext-1", "source_id" => local_list.id.to_s, "name" => "List",
            "items" => [
              { "id" => "ext-item-new", "source_id" => nil, "description" => "Buy milk", "completed" => false, "updated_at" => 1.minute.ago.iso8601 }
            ],
            "updated_at" => 2.hours.ago.iso8601
          }
        ])

        service.call

        new_item = local_list.todo_list_items.find_by(external_id: "ext-item-new")
        expect(new_item).to be_present
        expect(new_item.title).to eq("Buy milk")
      end
    end
  end
end
