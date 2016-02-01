require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/redis_token_store'

class GoogleClient
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Blue Yoshi'
  REDIS_KEY_PREFIX = 'blue-yoshi:g-user-token:'
  SCOPE = Google::Apis::GmailV1::AUTH_SCOPE

  CLIENT_SECRET_HASH = {
    'installed' => {
      'client_id' => ENV['GOOGLE_CLIENT_ID'],
      'project_id' => 'blue-yoshi',
      'auth_uri' => 'https://accounts.google.com/o/oauth2/auth',
      'token_uri' => 'https://accounts.google.com/o/oauth2/token',
      'auth_provider_x509_cert_url' => 'https://www.googleapis.com/oauth2/v1/certs',
      'client_secret' => ENV['GOOGLE_CLIENT_SECRET'],
      'redirect_uris' => ['urn:ietf:wg:oauth:2.0:oob', 'http://localhost']
    }
  }

  def send_message(mail)
    message = Google::Apis::GmailV1::Message.new(
      :raw => mail.to_s
    )

    service.send_user_message('me', message)
  end

  def list_user_labels
    user_id = 'me'
    result = service.list_user_labels(user_id)

    puts "Labels:"
    puts "No labels found" if result.labels.empty?
    result.labels.each { |label| puts "- #{label.name}" }
  end

  private

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def find_or_prompt_for_credentials
    client_id = Google::Auth::ClientId.from_hash(CLIENT_SECRET_HASH)
    token_store = Google::Auth::Stores::RedisTokenStore.new(:prefix => REDIS_KEY_PREFIX)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " +
           "resulting code after authorization:"
      puts url

      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end

    credentials
  end

  def service
    # Initialize the API
    service = Google::Apis::GmailV1::GmailService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = find_or_prompt_for_credentials

    service
  end
end
