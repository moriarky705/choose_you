# frozen_string_literal: true

# ルームアクセス認証を管理するサービス
class RoomAuthorizationService
  def initialize(room, params, cookies)
    @room = room
    @params = params
    @cookies = cookies
  end

  def authorized_user
    return owner_user if owner_access?
    return participant_user if participant_access?
    
    nil
  end

  def owner_access?
    return false unless @room
    
    token = owner_token
    token.present? && token == @room.owner_token
  end

  def participant_access?
    return false unless @room
    
    token = participant_token
    return false unless token
    
    @room.participants.any? { |p| p.token == token }
  end

  private

  def owner_user
    @owner_user ||= AuthorizedUser.new(
      type: :owner,
      name: @room.owner_name,
      token: @room.owner_token
    )
  end

  def participant_user
    token = participant_token
    participant = @room.participants.find { |p| p.token == token }
    return nil unless participant

    @participant_user ||= AuthorizedUser.new(
      type: :participant,
      name: participant.name,
      token: participant.token
    )
  end

  def owner_token
    @params[:owner_token] || @cookies.signed[:owner_token]
  end

  def participant_token
    cookie_key = "participant_token_#{@room.id}"
    @cookies.signed[cookie_key] || @params[:participant_token]
  end

  # 認証済みユーザーの情報を格納する値オブジェクト
  class AuthorizedUser
    attr_reader :type, :name, :token

    def initialize(type:, name:, token:)
      @type = type
      @name = name
      @token = token
    end

    def owner?
      @type == :owner
    end

    def participant?
      @type == :participant
    end
  end
end
