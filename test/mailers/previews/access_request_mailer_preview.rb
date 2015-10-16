# Preview all emails at http://localhost:3000/rails/mailers/access_request_mailer
require_relative '../../support/access_request_test_support'
class AccessRequestMailerPreview < ActionMailer::Preview
  include AccessRequestTestSupport
  def access_request_email
    enable_access_request
    user = User.new(name: 'Dummy User', email: 'dummy@example.com', )
    email = AccessRequestMailer.access_request_email('localhost', user, 'manager@example.com', 'Dummy reason.')
    restore_access_request_settings
    email
  end
end