module Api
  class SyncController < ApplicationController
    protect_from_forgery with: :null_session

    def create
      result = TodoSyncService.new.call

      render json: result, status: :ok
    end
  end
end
