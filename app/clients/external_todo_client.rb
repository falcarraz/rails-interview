class ExternalTodoClient
  class ApiError < StandardError; end
  class NotFoundError < ApiError; end
  class ServerError < ApiError; end

  MAX_RETRIES = 3
  TIMEOUT = 10

  def initialize(base_url: nil)
    @base_url = base_url || ENV.fetch("EXTERNAL_TODO_API_URL")
  end

  def fetch_all_lists
    response = connection.get("todolists")
    handle_response(response)
  end

  def create_list(source_id:, name:, items: [])
    body = { source_id: source_id.to_s, name: name, items: items }
    response = connection.post("todolists", body.to_json)
    handle_response(response)
  end

  def update_list(id, name:)
    response = connection.patch("todolists/#{id}", { name: name }.to_json)
    handle_response(response)
  end

  def delete_list(id)
    response = connection.delete("todolists/#{id}")
    handle_response(response)
  end

  def update_item(list_id, item_id, description:, completed:)
    body = { description: description, completed: completed }
    response = connection.patch("todolists/#{list_id}/todoitems/#{item_id}", body.to_json)
    handle_response(response)
  end

  def delete_item(list_id, item_id)
    response = connection.delete("todolists/#{list_id}/todoitems/#{item_id}")
    handle_response(response)
  end

  private

  def connection
    @connection ||= Faraday.new(url: @base_url) do |f|
      f.request :retry, max: MAX_RETRIES, interval: 0.5,
                backoff_factor: 2, retry_statuses: [429, 500, 502, 503]
      f.headers["Content-Type"] = "application/json"
      f.headers["Accept"] = "application/json"
      f.options.timeout = TIMEOUT
      f.options.open_timeout = 5
    end
  end

  def handle_response(response)
    case response.status
    when 200..299
      return nil if response.body.blank?
      JSON.parse(response.body)
    when 404
      raise NotFoundError, "Resource not found (404)"
    when 400..499
      raise ApiError, "Client error #{response.status}: #{response.body}"
    when 500..599
      raise ServerError, "Server error #{response.status}: #{response.body}"
    else
      raise ApiError, "Unexpected status #{response.status}: #{response.body}"
    end
  end
end
