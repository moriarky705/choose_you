# frozen_string_literal: true

class RoomsController < ApplicationController
  before_action :load_room, only: %i[show join select updates]

  def new
  end

  def create
    owner_name = params.require(:owner_name)
    room, owner_token = RoomRegistry.create_room(owner_name:)
    set_secure_cookie(:owner_token, owner_token)
    redirect_to room_path(room.id, owner_token:)
  end

  def show
    # 部屋の存在確認を強化（デバッグログ追加）
    Rails.logger.info "🔍 Room lookup: id=#{params[:id]}, @room=#{@room.present? ? 'found' : 'nil'}, registry_exists=#{RoomRegistry.room_exists?(params[:id])}"
    
    unless @room && RoomRegistry.room_exists?(@room.id)
      Rails.logger.warn "❌ Room not found: id=#{params[:id]}, @room=#{@room.present?}, registry_exists=#{RoomRegistry.room_exists?(params[:id])}"
      return redirect_to root_path, alert: '部屋が見つかりません。部屋が削除されたか、セッションが期限切れの可能性があります。'
    end

    authorized_user = authorization_service.authorized_user
    
    if authorized_user.nil?
      render :join_form and return
    end

    setup_participant_cookie(authorized_user) if authorized_user.participant?
    setup_show_variables(authorized_user)
  end

  def join
    Rails.logger.info "🚪 Join attempt: room_id=#{params[:id]}, already_joined=#{already_joined?}"
    
    return redirect_to_room_if_already_joined if already_joined?
    
    name = params.require(:name)
    participant = RoomRegistry.add_participant(room_id: params[:id], name:)
    
    Rails.logger.info "👤 Participant created: #{participant.present? ? 'success' : 'failed'}, room_exists=#{RoomRegistry.room_exists?(params[:id])}"
    
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
    Rails.logger.info "🏠 Load room: id=#{params[:id]}, found=#{@room.present?}"
  end

  def authorization_service
    @authorization_service ||= RoomAuthorizationService.new(@room, params, cookies)
  end

  def setup_participant_cookie(authorized_user)
    cookie_key = participant_cookie_key(@room.id)
    return if cookies.signed[cookie_key].present?
    
    set_secure_cookie(cookie_key, authorized_user.token)
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
    set_secure_cookie(participant_cookie_key(params[:id]), token)
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

  # Render.com対応のセキュアなCookie設定
  def set_secure_cookie(key, value)
    cookie_options = {
      value: value,
      expires: 240.hours.from_now,      # 明示的な期限設定
      secure: Rails.env.production?,   # 本番環境ではHTTPS必須
      httponly: true,                  # XSS対策
      same_site: :lax                  # CSRF対策
    }
    
    cookies.signed[key] = cookie_options
  end
end
