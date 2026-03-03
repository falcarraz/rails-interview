class ApplicationController < ActionController::Base
  rescue_from ActionController::UnknownFormat, with: :raise_not_found
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  def raise_not_found
    raise ActionController::RoutingError.new('Not supported format')
  end

  def render_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def render_unprocessable_entity(exception)
    render json: { errors: exception.record.errors }, status: :unprocessable_entity
  end

  def render_bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end
