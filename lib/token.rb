class Token
  DEFAULT_LENGTH = 16

  srand

  # Generates a random token
  #
  # The generated hexadecimal tokens are seeded with:
  # * The current time
  # * Random number between 0 and 1 (Kernel::rand)
  # * The current process ID
  #
  # By default the generated token will be 16 characters long, override this by
  # setting the <tt>:length</tt> option.
  #
  # Because of the universe, _and_ the fact that the tokens are cut off at the
  # +token_length+, there’s a slight chance that a token isn’t unique. Pesky
  # universe!
  def self.generate(options={})
    length = options[:length] || DEFAULT_LENGTH
    token = Digest::SHA1.hexdigest("#{Time.now}-#{Time.now.usec}-#{rand}-#{Process.pid}")
    token[0, length]
  end
end