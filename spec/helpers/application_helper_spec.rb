require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe 'application helper methods' do
    # 現在はカスタムヘルパーメソッドがないため、基本的なテストのみ
    it 'includes ActionView helpers' do
      expect(helper).to respond_to(:link_to)
      expect(helper).to respond_to(:form_with)
      expect(helper).to respond_to(:content_for)
    end
  end
end
