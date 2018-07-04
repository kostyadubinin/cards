if !ENV['SSL_KEY_PATH'].nil? && !ENV['SSL_CERT_PATH'].nil?
  ssl_bind "0.0.0.0", "9292", {
             key: ENV['SSL_KEY_PATH'],
             cert: ENV['SSL_CERT_PATH']
           }
end
