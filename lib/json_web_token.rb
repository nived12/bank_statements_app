class JsonWebToken
  # Access token expiration: 15 minutes
  ACCESS_TOKEN_EXPIRATION = 15.minutes

  # Refresh token expiration: 7 days
  REFRESH_TOKEN_EXPIRATION = 7.days

  # Encode a payload into a JWT token with standard claims
  # @param payload [Hash] The data to encode (must include user_id and jti)
  # @param expiration [ActiveSupport::Duration] Token expiration time
  # @return [String] Encoded JWT token
  def self.encode(payload, expiration = ACCESS_TOKEN_EXPIRATION)
    # Create a copy to avoid mutating the input
    jwt_payload = payload.dup

    # Add standard JWT claims
    jwt_payload[:exp] = expiration.from_now.to_i  # Expiration time
    jwt_payload[:iat] = Time.current.to_i         # Issued at
    jwt_payload[:nbf] = Time.current.to_i         # Not before (valid from now)
    jwt_payload[:iss] = JwtConfig.issuer          # Issuer
    jwt_payload[:aud] = JwtConfig.audience        # Audience

    JWT.encode(jwt_payload, JwtConfig.secret_key, "HS256")
  end

  # Decode a JWT token
  # @param token [String] The JWT token to decode
  # @return [Hash, nil] Decoded payload or nil if invalid
  def self.decode(token)
    # Verify issuer and audience claims
    body = JWT.decode(
      token,
      JwtConfig.secret_key,
      true,
      {
        algorithm: "HS256",
        verify_iss: true,
        iss: JwtConfig.issuer,
        verify_aud: true,
        aud: JwtConfig.audience
      }
    )[0]
    HashWithIndifferentAccess.new(body)
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidAudError => e
    Rails.logger.warn "JWT decode error: #{e.message}"
    nil
  end

  # Generate a unique JWT ID (jti)
  # Used to track and revoke specific tokens
  # @return [String] Unique identifier
  def self.generate_jti
    SecureRandom.uuid
  end

  # Generate an access token for a user
  # @param user [User] The user to generate token for
  # @return [String] Encoded access token
  def self.generate_access_token(user)
    encode(build_token_payload(user, "access"))
  end

  # Generate a refresh token for a user
  # @param user [User] The user to generate token for
  # @return [String] Encoded refresh token
  def self.generate_refresh_token(user)
    encode(build_token_payload(user, "refresh"), REFRESH_TOKEN_EXPIRATION)
  end

  # Build the base payload for a token
  # @param user [User] The user to generate token for
  # @param type [String] The token type ("access" or "refresh")
  # @return [Hash] Base payload with user info
  # @private
  def self.build_token_payload(user, type)
    {
      user_id: user.id,
      jti: user.jti,
      type: type
    }
  end
  private_class_method :build_token_payload
end
