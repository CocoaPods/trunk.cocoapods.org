require 'securerandom'

class Token
  class CollisionError < StandardError; end

  MAX_COLLISIONS = 10

  # Generates a random token and verifies it by yielding it to a block until
  # the return value of that block is `false` or `nil`.
  #
  # The `length` should be an even amount and currently defaults to 32.
  #
  def self.generate(length = nil, raise_after_collisions = MAX_COLLISIONS)
    # SecureRandom generates strings twice the size.
    length /= 2 if length
    count = 0
    token = nil
    loop do
      token = SecureRandom.hex(length)
      collision = yield(token)
      if collision
        count += 1
        if count == raise_after_collisions
          raise CollisionError, "#{raise_after_collisions} number of " \
            'collisions have occurred while generating a token.'
        end
      else
        break
      end
    end
    token
  end
end
