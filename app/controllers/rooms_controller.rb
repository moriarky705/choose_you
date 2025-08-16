# frozen_string_literal: true

class RoomsController < ApplicationController
  before_action :load_room, only: %i[show join select updates]

  def new
  end

  def create
    owner_name = params.require(:owner_name)
    room, owner_token = RoomRegistry.create_room(owner_name:)
    cookies.permanent.signed[:owner_token] = owner_token
    redirect_to room_path(room.id, owner_token:)
  end

  def show
    return redirect_to root_path, alert: '部屋が存在しません' unless @room

    authorized_user = authorization_service.authorized_user
    
    if authorized_user.nil?
      render :join_form and return
    end

    setup_participant_cookie(authorized_user) if authorized_user.participant?
    setup_show_variables(authorized_user)
  end

  def join
    return redirect_to_room_if_already_joined if already_joined?
    
    name = params.require(:name)
    participant = RoomRegistry.add_participant(room_id: params[:id], name:)
    
    if participant
      store_participant_cookie(participant.token)
      ActionCableBroadcastService.broadcast_participants_update(params[:id])
    end
    
    redirect_to room_path(params[:id], participant_token: participant&.token)
  end

  def select
    return head :forbidden unless authorization_service.owner_access?

    validation_error = validate_selection_params
    return validation_error if validation_error

    count = params[:count].to_i
    selected = RoomRegistry.select_random(room_id: params[:id], count:)
    
    # 抽選結果を配信
    ActionCableBroadcastService.broadcast_selection_update(params[:id], selected, count)
    # 参加者リストも同時に再配信（UIの整合性を保つため）
    ActionCableBroadcastService.broadcast_participants_update(params[:id])
    
    redirect_to room_path(params[:id], count: count)
  end

  def updates
    return head :not_found unless @room
    
    render json: room_updates_data
  end

  private

  def load_room
    @room = RoomRegistry.find_room(params[:id])
  end

  def authorization_service
    @authorization_service ||= RoomAuthorizationService.new(@room, params, cookies)
  end

  def setup_participant_cookie(authorized_user)
    cookie_key = participant_cookie_key(@room.id)
    return if cookies.signed[cookie_key].present?
    
    cookies.permanent.signed[cookie_key] = authorized_user.token
  end

  def setup_show_variables(authorized_user)
    @owner_view = authorized_user.owner?
    @participant = authorized_user.participant? ? authorized_user : nil
    @participants = RoomRegistry.participant_list(@room.id)
    @last_selection = @room.last_selection
    @last_count = params[:count]&.to_i || 1
  end

  def redirect_to_room_if_already_joined
    existing_token = cookies.signed[participant_cookie_key(params[:id])]
    return false unless existing_token
    
    existing_participant = RoomRegistry.participant_list(params[:id]).find { |p| p.token == existing_token }
    if existing_participant
      redirect_to room_path(params[:id])
      return true
    end
    false
  end

  def already_joined?
    existing_token = cookies.signed[participant_cookie_key(params[:id])]
    return false unless existing_token
    
    RoomRegistry.participant_list(params[:id]).any? { |p| p.token == existing_token }
  end

  def store_participant_cookie(token)
    cookies.permanent.signed[participant_cookie_key(params[:id])] = token
  end

  def validate_selection_params
    count = params[:count].to_i
    participants = RoomRegistry.participant_list(params[:id])
    
    if count <= 0
      redirect_to room_path(params[:id], count: count), alert: '1以上の人数を指定してください'
      return true
    end
    
    if count > participants.size
      redirect_to room_path(params[:id], count: count), alert: "参加者数(#{participants.size})以下の人数を指定してください"
      return true
    end
    
    false
  end

  def room_updates_data
    participants = RoomRegistry.participant_list(params[:id])
    data = { participants: participants.map { |p| { name: p.name } } }
    data[:selection] = @room.last_selection if @room.last_selection
    data
  end

  def participant_cookie_key(room_id)
    "participant_token_#{room_id}"
  end
end
