# frozen_string_literal: true

# ルームアクセス認証を管理するサービス
class RoomAuthorizationService
  def initialize(room, cookies)
    @room = room
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
    token.present? && ActiveSupport::SecurityUtils.secure_compare(token, @room.owner_token)
  end

  def participant_access?
    return false unless @room

    token = participant_token
    return false if token.blank?

    @room.participants.any? { |p| ActiveSupport::SecurityUtils.secure_compare(token, p.token) }
  end

  private

  def owner_user
    @owner_user ||= AuthorizedUser.new(
      type: :owner,
      name: @room.owner_name,
      token: @room.owner_token,
      id: @room.owner_id
    )
  end

  def participant_user
    token = participant_token
    participant = @room.participants.find { |p| ActiveSupport::SecurityUtils.secure_compare(token, p.token) }
    return nil unless participant

    @participant_user ||= AuthorizedUser.new(
      type: :participant,
      name: participant.name,
      token: participant.token,
      id: participant.id
    )
  end

  def owner_token
    @cookies.signed["owner_token_#{@room.id}"] || @cookies.signed[:owner_token]
  end

  def participant_token
    @cookies.signed["participant_token_#{@room.id}"]
  end

  # 認証済みユーザーの情報を格納する値オブジェクト
  class AuthorizedUser
    attr_reader :type, :name, :token, :id

    def initialize(type:, name:, token:, id:)
      @type = type
      @name = name
      @token = token
      @id = id
    end

    def owner?
      @type == :owner
    end

    def participant?
      @type == :participant
    end
  end
end
