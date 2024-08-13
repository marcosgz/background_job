# frozen_string_literal: true

require 'forwardable'

module BackgroundJob
  class RedisPool
    extend Forwardable
    def_delegator :@connection, :with

    module ConnectionPoolLike
      def with
        yield self
      end
    end

    def initialize(connection)
      if connection.respond_to?(:with)
        @connection = connection
      elsif connection.is_a?(::Redis)
        @connection = connection
        @connection.extend(ConnectionPoolLike)
      else
        @connection = connection ? ::Redis.new(connection) : ::Redis.new
        @connection.extend(ConnectionPoolLike)
      end
    end
  end
end
