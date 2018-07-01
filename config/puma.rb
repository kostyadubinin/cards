ssl_key_path = ENV["SSL_KEY_PATH"]
ssl_cert_path = ENV["SSL_CERT_PATH"]

if !ssl_key.nil? && !ssl_cert.nil?
  bind "ssl://0.0.0.0:9292?key=#{ssl_key_path}&cert=#{ssl_cert_path}"
end
