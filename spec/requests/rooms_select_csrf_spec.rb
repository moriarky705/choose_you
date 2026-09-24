require 'rails_helper'

RSpec.describe 'Rooms#select CSRF protection', type: :request do
  around do |example|
    orig = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = orig
  end

  it 'X-CSRF-Tokenがない場合は422、正しいトークンがある場合は200を返す' do
    get root_path
    authenticity_token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    expect(authenticity_token).to be_present

    post rooms_path, params: { owner_name: 'テストオーナー', authenticity_token: authenticity_token }
    expect(response).to have_http_status(:redirect)
    room_id = response.location.match(%r{/rooms/([a-z0-9]{6})})[1]

    post select_room_path(room_id), params: { count: '1' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    get room_path(room_id)
    csrf_token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    expect(csrf_token).to be_present

    post select_room_path(room_id),
      params: { count: '1' },
      headers: { 'X-CSRF-Token' => csrf_token },
      as: :json
    expect(response).to have_http_status(:success)
  end
end
