class TodoSyncService
  def initialize(client: ExternalTodoClient.new)
    @client = client
    @results = { success: [], failed: [] }
  end

  def call
    remote_lists = @client.fetch_all_lists
    local_lists = TodoList.includes(:todo_list_items).all.to_a

    remote_by_id = remote_lists.index_by { |r| r["id"] }
    remote_by_source_id = remote_lists.index_by { |r| r["source_id"] }
    matched_remote_ids = Set.new

    # Fase 1: procesar listas locales — push, pull o eliminar según corresponda
    local_lists.each do |local_list|
      sync_local_list(local_list, remote_by_id, remote_by_source_id, matched_remote_ids)
    end

    # Fase 2: importar listas remotas que no tienen contraparte local
    remote_lists.each do |remote_list|
      next if matched_remote_ids.include?(remote_list["id"])
      pull_new_remote_list(remote_list)
    end

    @results
  end

  private

  def sync_local_list(local_list, remote_by_id, remote_by_source_id, matched_remote_ids)
    if local_list.external_id.present?
      remote_list = remote_by_id[local_list.external_id]

      if remote_list
        matched_remote_ids.add(remote_list["id"])
        sync_matched_pair(local_list, remote_list)
      else
        # La lista fue eliminada del lado remoto: la destruimos localmente también
        Rails.logger.info("[Sync] List '#{local_list.name}' deleted remotely, destroying local ##{local_list.id}")
        local_list.destroy!
        @results[:success] << { id: local_list.id, action: :deleted_locally }
      end
    else
      # Caso borde: la lista fue pusheada antes pero no se guardó el external_id.
      # Intentamos recuperarla buscando por source_id en el remoto.
      remote_list = remote_by_source_id[local_list.id.to_s]

      if remote_list
        matched_remote_ids.add(remote_list["id"])
        local_list.update!(external_id: remote_list["id"])
        sync_matched_pair(local_list, remote_list)
      else
        push_new_local_list(local_list)
      end
    end
  rescue ExternalTodoClient::ApiError, ActiveRecord::ActiveRecordError => e
    # Aislamos el error por lista: si una falla, las demás continúan
    Rails.logger.error("[Sync] Failed for list ##{local_list.id}: #{e.message}")
    @results[:failed] << { id: local_list.id, error: e.message }
  end

  def sync_matched_pair(local_list, remote_list)
    local_changed = changed_since_sync?(local_list)
    remote_changed = remote_changed_since_sync?(remote_list, local_list.synced_at)

    if !local_changed && !remote_changed
      Rails.logger.debug("[Sync] List ##{local_list.id} already in sync")
    elsif local_changed && !remote_changed
      push_list_changes(local_list, remote_list)
    else
      # Ambos cambiaron o solo el remoto — el remoto gana para evitar merges complejos
      pull_list_changes(local_list, remote_list)
    end

    sync_items(local_list, remote_list)

    @results[:success] << { id: local_list.id, action: :synced }
  end

  def push_new_local_list(local_list)
    items = local_list.todo_list_items.map do |item|
      {
        source_id: item.id.to_s,
        description: TodoSync::FieldMapper.to_external_description(item.title, item.description),
        completed: item.completed
      }
    end

    result = @client.create_list(source_id: local_list.id, name: local_list.name, items: items)

    now = Time.current
    local_list.update!(external_id: result["id"], synced_at: now)

    map_item_external_ids(local_list, result["items"] || [], now)

    Rails.logger.info("[Sync] Pushed new list ##{local_list.id} → external #{result['id']}")
    @results[:success] << { id: local_list.id, action: :pushed_new }
  end

  def pull_new_remote_list(remote_list)
    ActiveRecord::Base.transaction do
      local_list = TodoList.create!(
        name: remote_list["name"],
        external_id: remote_list["id"],
        synced_at: Time.current
      )

      (remote_list["items"] || []).each do |remote_item|
        fields = TodoSync::FieldMapper.from_external_description(remote_item["description"])

        local_list.todo_list_items.create!(
          title: fields[:title],
          description: fields[:description],
          completed: remote_item["completed"] || false,
          external_id: remote_item["id"],
          synced_at: Time.current
        )
      end

      Rails.logger.info("[Sync] Pulled new remote list '#{local_list.name}' → local ##{local_list.id}")
      @results[:success] << { id: local_list.id, action: :pulled_new }
    end
  rescue ExternalTodoClient::ApiError, ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[Sync] Failed pulling remote list '#{remote_list['name']}': #{e.message}")
    @results[:failed] << { id: remote_list["id"], error: e.message }
  end

  def push_list_changes(local_list, remote_list)
    if local_list.name != remote_list["name"]
      @client.update_list(local_list.external_id, name: local_list.name)
    end
    local_list.update!(synced_at: Time.current)
    Rails.logger.info("[Sync] Pushed changes for list ##{local_list.id}")
  end

  def pull_list_changes(local_list, remote_list)
    local_list.update!(name: remote_list["name"], synced_at: Time.current)
    Rails.logger.info("[Sync] Pulled changes for list ##{local_list.id}")
  end

  # --- Sincronización de items ---

  def sync_items(local_list, remote_list)
    remote_items = remote_list["items"] || []

    # Primero propagamos las eliminaciones locales pendientes al remoto.
    # Devuelve los external_ids ya eliminados para filtrarlos del snapshot remoto
    # y evitar que sean re-importados como items nuevos en la siguiente fase.
    deleted_remote_ids = sync_tombstones(local_list)
    remote_items = remote_items.reject { |r| deleted_remote_ids.include?(r["id"]) }

    local_items = local_list.todo_list_items.to_a

    remote_items_by_id = remote_items.index_by { |r| r["id"] }
    remote_items_by_source_id = remote_items.index_by { |r| r["source_id"] }
    matched_remote_item_ids = Set.new
    has_new_local_items = false

    local_items.each do |local_item|
      if local_item.external_id.present?
        remote_item = remote_items_by_id[local_item.external_id]

        if remote_item
          matched_remote_item_ids.add(remote_item["id"])
          sync_matched_item(local_list, local_item, remote_item)
        else
          # El item fue eliminado del lado remoto: lo eliminamos localmente
          local_item.destroy!
        end
      else
        # Caso borde: mismo mecanismo de recuperación por source_id que en listas
        remote_item = remote_items_by_source_id[local_item.id.to_s]

        if remote_item
          matched_remote_item_ids.add(remote_item["id"])
          local_item.update!(external_id: remote_item["id"])
          sync_matched_item(local_list, local_item, remote_item)
        else
          has_new_local_items = true
        end
      end
    end

    # Importar items que existen en el remoto pero no localmente
    remote_items.each do |remote_item|
      next if matched_remote_item_ids.include?(remote_item["id"])
      pull_new_remote_item(local_list, remote_item)
    end

    # La API externa no permite agregar items a una lista existente.
    # Usamos delete+recreate como fallback cuando hay items locales nuevos.
    rebuild_remote_list_to_add_missing_items(local_list) if has_new_local_items
  end

  def sync_matched_item(local_list, local_item, remote_item)
    local_changed = changed_since_sync?(local_item)
    remote_changed = remote_changed_since_sync?(remote_item, local_item.synced_at)

    if !local_changed && !remote_changed
      return
    elsif local_changed && !remote_changed
      push_item_changes(local_list, local_item)
    else
      # Conflicto o cambio remoto: el remoto gana
      pull_item_changes(local_item, remote_item)
    end
  end

  def push_item_changes(local_list, local_item)
    description = TodoSync::FieldMapper.to_external_description(local_item.title, local_item.description)
    @client.update_item(local_list.external_id, local_item.external_id,
                        description: description, completed: local_item.completed)
    local_item.update!(synced_at: Time.current)
  end

  def pull_item_changes(local_item, remote_item)
    fields = TodoSync::FieldMapper.from_external_description(remote_item["description"])
    local_item.update!(
      title: fields[:title],
      description: fields[:description],
      completed: remote_item["completed"] || false,
      synced_at: Time.current
    )
  end

  # Busca items soft-deleted localmente que todavía tienen external_id (tombstones).
  # Para cada uno: intenta DELETE en el remoto, luego hard-delete local.
  # Si el remoto ya no tiene el item (404), igual lo hard-deletea localmente.
  # Devuelve el conjunto de external_ids procesados para que sync_items los excluya
  # del snapshot remoto y no los re-importe como items nuevos.
  def sync_tombstones(local_list)
    deleted_remote_ids = Set.new

    TodoListItem.unscoped
      .where(todo_list_id: local_list.id)
      .where.not(deleted_at: nil)
      .where.not(external_id: nil)
      .each do |item|
        begin
          @client.delete_item(local_list.external_id, item.external_id)
          deleted_remote_ids.add(item.external_id)
          Rails.logger.info("[Sync] Deleted remote item #{item.external_id} for local item ##{item.id}")
        rescue ExternalTodoClient::NotFoundError
          # Ya fue eliminado remotamente — aceptamos el estado y hard-deleteamos local
          deleted_remote_ids.add(item.external_id)
          Rails.logger.info("[Sync] Remote item #{item.external_id} already gone, cleaning up local ##{item.id}")
        end
        item.destroy! # hard delete: el tombstone cumplió su función
      end

    deleted_remote_ids
  end

  def pull_new_remote_item(local_list, remote_item)
    fields = TodoSync::FieldMapper.from_external_description(remote_item["description"])
    local_list.todo_list_items.create!(
      title: fields[:title],
      description: fields[:description],
      completed: remote_item["completed"] || false,
      external_id: remote_item["id"],
      synced_at: Time.current
    )
  end

  def rebuild_remote_list_to_add_missing_items(local_list)
    local_list.reload

    # Tomamos un snapshot completo del payload antes de cualquier operación destructiva.
    # Si el recreate falla después del delete, este snapshot queda en el log para
    # poder reconstruir la lista manualmente o que el próximo sync la vuelva a pushear.
    items_payload = local_list.todo_list_items.map do |item|
      {
        source_id: item.id.to_s,
        description: TodoSync::FieldMapper.to_external_description(item.title, item.description),
        completed: item.completed
      }
    end

    old_external_id = local_list.external_id
    @client.delete_list(old_external_id)

    begin
      result = @client.create_list(source_id: local_list.id, name: local_list.name, items: items_payload)
    rescue ExternalTodoClient::ApiError => e
      # El delete fue exitoso pero el recreate falló.
      # Limpiamos el external_id para que el próximo sync trate esta lista como nueva
      # y la vuelva a pushear, en lugar de detectarla como "eliminada remotamente"
      # y destruir los datos locales.
      local_list.update_column(:external_id, nil)
      Rails.logger.error(
        "[Sync] CRITICAL: Deleted remote list #{old_external_id} but failed to recreate it. " \
        "Local list ##{local_list.id} external_id cleared — will be re-pushed on next sync. " \
        "Payload snapshot: #{items_payload.to_json}"
      )
      raise
    end

    now = Time.current
    local_list.update!(external_id: result["id"], synced_at: now)
    map_item_external_ids(local_list, result["items"] || [], now)

    Rails.logger.info("[Sync] Rebuilt remote list ##{local_list.id} (#{old_external_id} → #{result['id']}) to include new items")
  end

  # --- Helpers ---

  def changed_since_sync?(record)
    record.synced_at.nil? || record.updated_at > record.synced_at
  end

  def remote_changed_since_sync?(remote_hash, synced_at)
    return true if synced_at.nil?

    remote_updated = Time.parse(remote_hash["updated_at"]) rescue nil
    return true if remote_updated.nil?

    remote_updated > synced_at
  end

  def map_item_external_ids(local_list, remote_items, synced_at)
    # Indexamos en memoria para evitar un query por item al matchear source_id
    local_items_by_id = local_list.todo_list_items.index_by { |item| item.id.to_s }
    remote_items.each do |remote_item|
      local_item = local_items_by_id[remote_item["source_id"]]
      local_item&.update!(external_id: remote_item["id"], synced_at: synced_at)
    end
  end
end
