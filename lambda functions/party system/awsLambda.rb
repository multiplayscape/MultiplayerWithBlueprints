require 'aws-sdk-kms'
require 'aws-sdk-dynamodb'
require 'aws-sdk-cognitoidentityprovider'
require 'aws-sdk-ses'
require 'base64'
require 'json'

UserActivitiesTableNameEncrypted = ENV['user_activities_table']
UserActivitiesTableNameDecrypted = Aws::KMS::Client.new
                                       .decrypt({ciphertext_blob: Base64.decode64(UserActivitiesTableNameEncrypted)})
                                       .plaintext

InvitationTableNameEncrypted = ENV['invitation_table']
InvitationTableNameDecrypted = Aws::KMS::Client.new
                                   .decrypt({ciphertext_blob: Base64.decode64(InvitationTableNameEncrypted)})
                                   .plaintext

DynamoDBRegionEncrypted = ENV['dynamodb_region']
DynamoDBRegionDecrypted = Aws::KMS::Client.new
                              .decrypt({ciphertext_blob: Base64.decode64(DynamoDBRegionEncrypted)})
                              .plaintext

DynamoDB = Aws::DynamoDB::Client.new(
    region: DynamoDBRegionDecrypted,
)

CognitoUserPoolIdEncrypted = ENV['user_pool_id']
CognitoUserPoolIdDecrypted = Aws::KMS::Client.new
                                 .decrypt({ciphertext_blob: Base64.decode64(CognitoUserPoolIdEncrypted)})
                                 .plaintext

CognitoRegionEncrypted = ENV['cognito_region']
CognitoRegionDecrypted = Aws::KMS::Client.new
                             .decrypt({ciphertext_blob: Base64.decode64(CognitoRegionEncrypted)})
                             .plaintext

CognitoIdp = Aws::CognitoIdentityProvider::Client.new(
    region: CognitoRegionDecrypted,
)


EmailSenderEncrypted = ENV['email_sender']
EmailSenderDecrypted = Aws::KMS::Client.new
                           .decrypt({ciphertext_blob: Base64.decode64(EmailSenderEncrypted)})
                           .plaintext

SESRegionEncrypted = ENV['ses_region']
SESRegionDecrypted = Aws::KMS::Client.new
                         .decrypt({ciphertext_blob: Base64.decode64(SESRegionEncrypted)})
                         .plaintext

SES = Aws::SES::Client.new(
    region: SESRegionDecrypted,
)

def get_latence(event:, context:)
  (Time.now.to_f * 1000).to_i - event.to_i
end

def get_timestamp(event:, context:)
  Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')
end

def heart_beats(event:, context:)
  heart_beat = event
  heart_beat['expire_time'] = Time.now.to_f.to_i + 10

  begin
    DynamoDB.update_item({
                             table_name: UserActivitiesTableNameDecrypted,
                             key: {
                                 'user-sub': heart_beat['user']
                             },
                             update_expression: 'set activities = :activities, gamelift_region = :region, #expire_time = :expire_time',
                             expression_attribute_values: {
                                 ':activities' => heart_beat['activities'],
                                 ':region' => heart_beat['region'],
                                 ':expire_time' => heart_beat['expire_time'],
                             },
                             expression_attribute_names: {
                                 "#expire_time" => "expire-time"
                             }
                         })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to update item in ' + UserActivitiesTableNameDecrypted + ': '
    puts error.message
  end
end

def invite_friend(event:, context:)
  invitation = event
  invitation['expire_time'] = Time.now.to_f.to_i + 10

  begin
    DynamoDB.put_item({
                          table_name: InvitationTableNameDecrypted,
                          item: {
                              'from-user-sub': invitation['from'],
                              'to-user-sub': invitation['to'],
                              'gamelift_region': invitation['region'],
                              'game_session': invitation['game_session'],
                              'expire-time': invitation['expire_time'],
                          }
                      })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to put item in ' + InvitationTableNameDecrypted + ': '
    puts error.message
    return
  end

#   send an email if the user is not online
  begin
    result = DynamoDB.get_item({
                                   table_name: UserActivitiesTableNameDecrypted,
                                   key: {
                                       'user-sub': invitation['to']
                                   }
                               })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + UserActivitiesTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result.item == nil
    begin
      result = CognitoIdp.list_users({
                                         user_pool_id: CognitoUserPoolIdDecrypted,
                                         filter: 'sub="%s"' % [invitation['to']]
                                     })
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => error
      puts 'Unable to list users.'
      puts error.message
      return
    end

    if result.users.length > 0
      begin
        SES.send_email(
            destination: {
                to_addresses: [
                    result.users.at(0).attributes.select { |attribute| attribute.name == "email" }[0].value
                ]
            },
            message: {
                body: {
                    html: {
                        charset: 'UTF-8',
                        data:
                            '<h1>Amazon SES test (AWS SDK for Ruby)</h1>'\
  '<p>This email was sent with <a href="https://aws.amazon.com/ses/">'\
  'Amazon SES</a> using the <a href="https://aws.amazon.com/sdk-for-ruby/">'\
  'AWS SDK for Ruby</a>. add your app launch url here.</p>'
                    },
                    text: {
                        charset: 'UTF-8',
                        data: 'This email was sent with Amazon SES using the AWS SDK for Ruby.'
                    }
                },
                subject: {
                    charset: 'UTF-8',
                    data: 'Amazon SES test (AWS SDK for Ruby)'
                }
            },
            source: EmailSenderDecrypted,
            configuration_set_name: "",
        )
      rescue Aws::SES::Errors::ServiceError => error
        puts "Email not sent. Error message: #{error}"
      end
    end
  end
end

def get_invitation(event:, context:)
  invitation = event
  invitation['expire_time'] = Time.now.to_f.to_i - 10

  begin
    result = DynamoDB.query({
                                table_name: InvitationTableNameDecrypted,
                                key_condition_expression: "#to_user_sub = :to_user_sub and #expire_time >= :expire_time",
                                expression_attribute_names: {
                                    "#to_user_sub" => "to-user-sub",
                                    "#expire_time" => "expire-time",
                                },
                                expression_attribute_values: {
                                    ":to_user_sub" => invitation["to"],
                                    ':expire_time' => invitation['expire_time'],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + InvitationTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil && result.items.length > 0
    invite = result.items.max_by { |item| item["expire-time"] }
    {
        'region': invite['gamelift_region'],
        'game_session': invite['game_session'],
        'from': invite['from-user-sub'],
    }
  else
    {}
  end
end