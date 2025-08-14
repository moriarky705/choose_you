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

    @owner_view = owner_token_matches?
    participant_token = cookies.signed[participant_cookie_key(@room.id)] || params[:participant_token]
    if participant_token && cookies.signed[participant_cookie_key(@room.id)].blank?
      cookies.permanent.signed[participant_cookie_key(@room.id)] = participant_token
    end
    @participant = find_participant(@room, participant_token)

    if !@owner_view && @participant.nil?
      render :join_form and return
    end

    @participants = RoomRegistry.participant_list(@room.id)
    @last_selection = @room.last_selection
    @last_count = params[:count]&.to_i || 1  # 抽選人数を保持
  end

  def join
    # 既にこの部屋の参加者であれば何もしない
    existing_token = cookies.signed[participant_cookie_key(params[:id])]
    if existing_token
      existing = RoomRegistry.participant_list(params[:id]).find { |p| p.token == existing_token }
      return redirect_to room_path(params[:id]) if existing
    end

    name = params.require(:name)
    participant = RoomRegistry.add_participant(room_id: params[:id], name:)
    cookies.permanent.signed[participant_cookie_key(params[:id])] = participant.token if participant
    
    # ActionCableでブロードキャスト（エラー時はスキップ）
    begin
      ActionCable.server.broadcast("room_#{params[:id]}", { type: 'participants', participants: RoomRegistry.participant_list(params[:id]).map { |p| { name: p.name } } })
    rescue => e
      Rails.logger.warn "ActionCable broadcast failed: #{e.message}"
    end
    
    redirect_to room_path(params[:id], participant_token: participant&.token)
  end

  def select
    unless owner_token_matches?
      head :forbidden and return
    end
    count = params[:count].to_i
    participants = RoomRegistry.participant_list(params[:id])
    if count <= 0
      redirect_to room_path(params[:id], count: count), alert: '1以上の人数を指定してください' and return
    end
    if count > participants.size
      redirect_to room_path(params[:id], count: count), alert: "参加者数(#{participants.size})以下の人数を指定してください" and return
    end
    selected = RoomRegistry.select_random(room_id: params[:id], count:)
    
    # ActionCableでブロードキャスト（エラー時はスキップ）
    begin
      ActionCable.server.broadcast("room_#{params[:id]}", { type: 'selection', selected: selected.map { |p| { name: p.name } }, count: count })
    rescue => e
      Rails.logger.warn "ActionCable broadcast failed: #{e.message}"
    end
    
    redirect_to room_path(params[:id], count: count)
  end

  def updates
    return head :not_found unless @room
    
    participants = RoomRegistry.participant_list(params[:id])
    data = {
      participants: participants.map { |p| { name: p.name } }
    }
    
    if @room.last_selection
      data[:selection] = @room.last_selection
    end
    
    render json: data
  end

  private

  def load_room
    @room = RoomRegistry.find_room(params[:id])
  end

  def owner_token_matches?
    token = params[:owner_token] || cookies.signed[:owner_token]
    @room && token == @room.owner_token
  end

  def find_participant(room, token)
    return nil unless room && token
    room.participants.find { |p| p.token == token }
  end

  def participant_cookie_key(room_id)
    "participant_token_#{room_id}"
  end
end
