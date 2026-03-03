require 'rails_helper'

RSpec.describe TodoSync::FieldMapper do
  describe '.to_external_description' do
    it 'concatenates title and description' do
      result = described_class.to_external_description('Buy groceries', 'milk and eggs')

      expect(result).to eq('Buy groceries: milk and eggs')
    end

    it 'returns just the title when description is blank' do
      result = described_class.to_external_description('Buy groceries', '')

      expect(result).to eq('Buy groceries')
    end

    it 'returns just the title when description is nil' do
      result = described_class.to_external_description('Buy groceries', nil)

      expect(result).to eq('Buy groceries')
    end
  end

  describe '.from_external_description' do
    it 'splits on the first separator' do
      result = described_class.from_external_description('Buy groceries: milk and eggs')

      expect(result).to eq({ title: 'Buy groceries', description: 'milk and eggs' })
    end

    it 'handles descriptions with multiple separators' do
      result = described_class.from_external_description('Note: first: second')

      expect(result).to eq({ title: 'Note', description: 'first: second' })
    end

    it 'sets title to the full string when no separator found' do
      result = described_class.from_external_description('Simple task')

      expect(result).to eq({ title: 'Simple task', description: '' })
    end

    it 'handles blank input' do
      result = described_class.from_external_description('')

      expect(result).to eq({ title: '', description: '' })
    end

    it 'handles nil input' do
      result = described_class.from_external_description(nil)

      expect(result).to eq({ title: '', description: '' })
    end
  end
end
