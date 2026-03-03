require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ExternalTodoClient do
  let(:base_url) { 'http://external-api.test' }
  let(:client) { described_class.new(base_url: base_url) }

  describe '#fetch_all_lists' do
    it 'returns parsed JSON array' do
      stub_request(:get, "#{base_url}/todolists")
        .to_return(status: 200, body: [{ id: 'abc', name: 'Test' }].to_json)

      result = client.fetch_all_lists

      expect(result).to eq([{ 'id' => 'abc', 'name' => 'Test' }])
    end

    it 'raises ServerError on 500' do
      stub_request(:get, "#{base_url}/todolists")
        .to_return(status: 500, body: 'Internal error')

      expect { client.fetch_all_lists }.to raise_error(ExternalTodoClient::ServerError)
    end
  end

  describe '#create_list' do
    it 'posts and returns the created list' do
      stub_request(:post, "#{base_url}/todolists")
        .with(body: { source_id: '1', name: 'My List', items: [] }.to_json)
        .to_return(status: 201, body: { id: 'abc', name: 'My List' }.to_json)

      result = client.create_list(source_id: 1, name: 'My List')

      expect(result['id']).to eq('abc')
    end
  end

  describe '#update_list' do
    it 'patches the list name' do
      stub_request(:patch, "#{base_url}/todolists/abc")
        .with(body: { name: 'Updated' }.to_json)
        .to_return(status: 200, body: { id: 'abc', name: 'Updated' }.to_json)

      result = client.update_list('abc', name: 'Updated')

      expect(result['name']).to eq('Updated')
    end

    it 'raises NotFoundError on 404' do
      stub_request(:patch, "#{base_url}/todolists/missing")
        .to_return(status: 404, body: 'Not found')

      expect { client.update_list('missing', name: 'X') }.to raise_error(ExternalTodoClient::NotFoundError)
    end
  end

  describe '#delete_list' do
    it 'deletes and returns nil' do
      stub_request(:delete, "#{base_url}/todolists/abc")
        .to_return(status: 204, body: '')

      result = client.delete_list('abc')

      expect(result).to be_nil
    end
  end

  describe '#update_item' do
    it 'patches the item' do
      stub_request(:patch, "#{base_url}/todolists/abc/todoitems/xyz")
        .with(body: { description: 'Updated', completed: true }.to_json)
        .to_return(status: 200, body: { id: 'xyz', description: 'Updated', completed: true }.to_json)

      result = client.update_item('abc', 'xyz', description: 'Updated', completed: true)

      expect(result['completed']).to be true
    end
  end

  describe '#delete_item' do
    it 'deletes and returns nil' do
      stub_request(:delete, "#{base_url}/todolists/abc/todoitems/xyz")
        .to_return(status: 204, body: '')

      result = client.delete_item('abc', 'xyz')

      expect(result).to be_nil
    end
  end
end
