require 'aws-sdk-kms'
require 'aws-sdk-dynamodb'
require 'aws-sdk-cognitoidentityprovider'
require 'aws-sdk-ses'
require 'base64'
require 'json'

FriendTableNameEncrypted = ENV['friend_table']
FriendTableNameDecrypted = Aws::KMS::Client.new
                               .decrypt({ciphertext_blob: Base64.decode64(FriendTableNameEncrypted)})
                               .plaintext

FriendTableBySubIdIndexNameEncrypted = ENV['friend_table_bySubId_index']
FriendTableBySubIdIndexNameDecrypted = Aws::KMS::Client.new
                                           .decrypt({ciphertext_blob: Base64.decode64(FriendTableBySubIdIndexNameEncrypted)})
                                           .plaintext

FriendTableByFriendSubIdIndexNameEncrypted = ENV['friend_table_byFriendSubId_index']
FriendTableByFriendSubIdIndexNameDecrypted = Aws::KMS::Client.new
                                                 .decrypt({ciphertext_blob: Base64.decode64(FriendTableByFriendSubIdIndexNameEncrypted)})
                                                 .plaintext

FriendTableByFriendStatusIndexNameEncrypted = ENV['friend_table_byFriendStatus_index']
FriendTableByFriendStatusIndexNameDecrypted = Aws::KMS::Client.new
                                                 .decrypt({ciphertext_blob: Base64.decode64(FriendTableByFriendStatusIndexNameEncrypted)})
                                                 .plaintext

DynamoDBRegionEncrypted = ENV['dynamodb_region']
DynamoDBRegionDecrypted = Aws::KMS::Client.new
                              .decrypt({ciphertext_blob: Base64.decode64(DynamoDBRegionEncrypted)})
                              .plaintext

DynamoDB = Aws::DynamoDB::Client.new(
    region: DynamoDBRegionDecrypted,
)

def send_friend_request(event:, context:)
  friend_request = event

  begin
    result = DynamoDB.scan({
                               table_name: FriendTableNameDecrypted,
                               index_name: FriendTableBySubIdIndexNameDecrypted,
                               filter_expression: "#subId = :subId and #friendSubId = :friendSubId",
                               expression_attribute_names: {
                                   "#subId" => "subId",
                                   "#friendSubId" => "friendSubId",
                               },
                               expression_attribute_values: {
                                   ":subId" => friend_request["from"],
                                   ':friendSubId' => friend_request['to'],
                               },
                           })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil && result.items.length > 0
    if result.items[0]['friendStatus'] == 'deleted_request' || result.items[0]['friendStatus'] == 'request_rejected' || result.items[0]['friendStatus'] == 'rejected_request'
      begin
        DynamoDB.update_item({
                                 table_name: FriendTableNameDecrypted,
                                 key: {
                                     'id': friend_request["from"] + '#' + friend_request['to']
                                 },
                                 update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                                 expression_attribute_values: {
                                     ':subId' => friend_request["from"],
                                     ':friendSubId' => friend_request['to'],
                                     ':friendStatus' => 'request_sent',
                                 },
                             })
      rescue Aws::DynamoDB::Errors::ServiceError => error
        puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
        puts error.message
      end

      begin
        DynamoDB.update_item({
                                 table_name: FriendTableNameDecrypted,
                                 key: {
                                     'id': friend_request["to"] + '#' + friend_request['from']
                                 },
                                 update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                                 expression_attribute_values: {
                                     ':subId' => friend_request["to"],
                                     ':friendSubId' => friend_request['from'],
                                     ':friendStatus' => 'received_request',
                                 },
                             })
      rescue Aws::DynamoDB::Errors::ServiceError => error
        puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
        puts error.message
      end

      {
          'status': 'success',
          'reason': 'previous friend status: ' + result.items[0]['friendStatus'],
      }
    else
      {
          'status': 'failed',
          'reason': 'friend status exists. status: ' + result.items[0]['friendStatus'],
      }
    end
  else
    begin
      DynamoDB.update_item({
                               table_name: FriendTableNameDecrypted,
                               key: {
                                   'id': friend_request["from"] + '#' + friend_request['to']
                               },
                               update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                               expression_attribute_values: {
                                   ':subId' => friend_request["from"],
                                   ':friendSubId' => friend_request['to'],
                                   ':friendStatus' => 'request_sent',
                               },
                           })
    rescue Aws::DynamoDB::Errors::ServiceError => error
      puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
      puts error.message
    end

    begin
      DynamoDB.update_item({
                               table_name: FriendTableNameDecrypted,
                               key: {
                                   'id': friend_request["to"] + '#' + friend_request['from']
                               },
                               update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                               expression_attribute_values: {
                                   ':subId' => friend_request["to"],
                                   ':friendSubId' => friend_request['from'],
                                   ':friendStatus' => 'received_request',
                               },
                           })
    rescue Aws::DynamoDB::Errors::ServiceError => error
      puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
      puts error.message
    end

    {
        'status': 'success',
        'reason': '',
    }
  end
end

def accept_friend_request(event:, context:)
  friend_request = event

  begin
    result = DynamoDB.scan({
                                table_name: FriendTableNameDecrypted,
                                index_name: FriendTableBySubIdIndexNameDecrypted,
                                filter_expression: "#subId = :subId and #friendSubId = :friendSubId",
                                expression_attribute_names: {
                                    "#subId" => "subId",
                                    "#friendSubId" => "friendSubId",
                                },
                                expression_attribute_values: {
                                    ":subId" => friend_request["from"],
                                    ':friendSubId' => friend_request['to'],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil && result.items.length > 0
    if result.items[0]['friendStatus'] == 'received_request'
      begin
        DynamoDB.update_item({
                                 table_name: FriendTableNameDecrypted,
                                 key: {
                                     'id': friend_request["from"] + '#' + friend_request['to']
                                 },
                                 update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                                 expression_attribute_values: {
                                     ':subId' => friend_request["from"],
                                     ':friendSubId' => friend_request['to'],
                                     ':friendStatus' => 'accepted_request',
                                 },
                             })
      rescue Aws::DynamoDB::Errors::ServiceError => error
        puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
        puts error.message
      end

      begin
        DynamoDB.update_item({
                                 table_name: FriendTableNameDecrypted,
                                 key: {
                                     'id': friend_request["to"] + '#' + friend_request['from']
                                 },
                                 update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                                 expression_attribute_values: {
                                     ':subId' => friend_request["to"],
                                     ':friendSubId' => friend_request['from'],
                                     ':friendStatus' => 'request_accepted',
                                 },
                             })
      rescue Aws::DynamoDB::Errors::ServiceError => error
        puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
        puts error.message
      end

      {
          'status': 'success',
          'reason': 'previous friend status: received_request' + result.items[0]['friendStatus'],
      }
    else
      {
          'status': 'failed',
          'reason': 'friend status is not received_request. status: ' + result.items[0]['friendStatus'],
      }
    end
  else
    {
        'status': 'failed',
        'reason': 'friend status doesn\'t exist',
    }
  end
end

def rejected_friend_request(event:, context:)
  friend_request = event

  begin
    result = DynamoDB.scan({
                                table_name: FriendTableNameDecrypted,
                                index_name: FriendTableBySubIdIndexNameDecrypted,
                                filter_expression: "#subId = :subId and #friendSubId = :friendSubId",
                                expression_attribute_names: {
                                    "#subId" => "subId",
                                    "#friendSubId" => "friendSubId",
                                },
                                expression_attribute_values: {
                                    ":subId" => friend_request["from"],
                                    ':friendSubId' => friend_request['to'],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil && result.items.length > 0
    if result.items[0]['friendStatus'] == 'received_request'
      begin
        DynamoDB.update_item({
                                 table_name: FriendTableNameDecrypted,
                                 key: {
                                     'id': friend_request["from"] + '#' + friend_request['to']
                                 },
                                 update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                                 expression_attribute_values: {
                                     ':subId' => friend_request["from"],
                                     ':friendSubId' => friend_request['to'],
                                     ':friendStatus' => 'rejected_request',
                                 },
                             })
      rescue Aws::DynamoDB::Errors::ServiceError => error
        puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
        puts error.message
      end

      begin
        DynamoDB.update_item({
                                 table_name: FriendTableNameDecrypted,
                                 key: {
                                     'id': friend_request["to"] + '#' + friend_request['from']
                                 },
                                 update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                                 expression_attribute_values: {
                                     ':subId' => friend_request["to"],
                                     ':friendSubId' => friend_request['from'],
                                     ':friendStatus' => 'request_rejected',
                                 },
                             })
      rescue Aws::DynamoDB::Errors::ServiceError => error
        puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
        puts error.message
      end

      {
          'status': 'success',
          'reason': 'previous friend status: received_request' + result.items[0]['friendStatus'],
      }
    else
      {
          'status': 'failed',
          'reason': 'friend status is not received_request. status: ' + result.items[0]['friendStatus'],
      }
    end
  else
    {
        'status': 'failed',
        'reason': 'friend status doesn\'t exist',
    }
  end
end

def delete_friend_request(event:, context:)
  friend_request = event

  begin
    result = DynamoDB.scan({
                                table_name: FriendTableNameDecrypted,
                                index_name: FriendTableBySubIdIndexNameDecrypted,
                                filter_expression: "#subId = :subId and #friendSubId = :friendSubId",
                                expression_attribute_names: {
                                    "#subId" => "subId",
                                    "#friendSubId" => "friendSubId",
                                },
                                expression_attribute_values: {
                                    ":subId" => friend_request["from"],
                                    ':friendSubId' => friend_request['to'],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil && result.items.length > 0
    begin
      DynamoDB.update_item({
                               table_name: FriendTableNameDecrypted,
                               key: {
                                   'id': friend_request["from"] + '#' + friend_request['to']
                               },
                               update_expression: 'set subId = :subId, friendSubId = :friendSubId, friendStatus = :friendStatus',
                               expression_attribute_values: {
                                   ':subId' => friend_request["from"],
                                   ':friendSubId' => friend_request['to'],
                                   ':friendStatus' => 'deleted_request',
                               },
                           })
    rescue Aws::DynamoDB::Errors::ServiceError => error
      puts 'Unable to update item in ' + FriendTableNameDecrypted + ': '
      puts error.message
    end
  else
    {
        'status': 'failed',
        'reason': 'friend status doesn\'t exist',
    }
  end
end

def list_friends_bySubId(event:, context:)
  user = event

  begin
    result = DynamoDB.scan({
                                table_name: FriendTableNameDecrypted,
                                index_name: FriendTableBySubIdIndexNameDecrypted,
                                filter_expression: "#subId = :subId",
                                expression_attribute_names: {
                                    "#subId" => "subId",
                                },
                                expression_attribute_values: {
                                    ":subId" => user["subId"],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil
    {
        'status': 'success',
        'reason': '',
        'items': result.items,
    }
  else
    {
        'status': 'failed',
        'reason': 'nil result',
    }
  end
end

def list_friends_byFriendSubId(event:, context:)
  user = event

  begin
    result = DynamoDB.scan({
                                table_name: FriendTableNameDecrypted,
                                index_name: FriendTableByFriendSubIdIndexNameDecrypted,
                                filter_expression: "#subId = :subId and #friendSubId = :friendSubId",
                                expression_attribute_names: {
                                    "#subId" => "subId",
                                    "#friendSubId" => "friendSubId",
                                },
                                expression_attribute_values: {
                                    ":subId" => user["subId"],
                                    ':friendSubId' => user['friendSubId'],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil
    {
        'status': 'success',
        'reason': '',
        'items': result.items,
    }
  else
    {
        'status': 'failed',
        'reason': 'nil result',
    }
  end
end

def list_friends_byFriendStatus(event:, context:)
  user = event

  begin
    result = DynamoDB.scan({
                                table_name: FriendTableNameDecrypted,
                                index_name: FriendTableByFriendStatusIndexNameDecrypted,
                                filter_expression: "#subId = :subId and #friendStatus = :friendStatus",
                                expression_attribute_names: {
                                    "#subId" => "subId",
                                    "#friendStatus" => "friendStatus",
                                },
                                expression_attribute_values: {
                                    ":subId" => user["subId"],
                                    ':friendStatus' => user['friendStatus'],
                                },
                            })
  rescue Aws::DynamoDB::Errors::ServiceError => error
    puts 'Unable to get item in ' + FriendTableNameDecrypted + ': '
    puts error.message
    return
  end

  if result != nil
    {
        'status': 'success',
        'reason': '',
        'items': result.items,
    }
  else
    {
        'status': 'failed',
        'reason': 'nil result',
    }
  end
end
