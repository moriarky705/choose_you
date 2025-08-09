# frozen_string_literal: true

require 'securerandom'

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :request_id

    def connect
      self.request_id = SecureRandom.hex(8)
    end
  end
end
