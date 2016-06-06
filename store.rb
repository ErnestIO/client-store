# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'sinatra'
require 'sequel'
require 'flowauth'
require 'yaml'
require 'nats/client'

module Config
  def self.load_db
    NATS.start(servers: [ENV['NATS_URI']]) do
      NATS.request('config.get.postgres') do |r|
        return JSON.parse(r, symbolize_names: true)
      end
    end
  end
  def self.load_redis
    return nil if ENV['RACK_ENV'] == 'test'
    NATS.start(servers: [ENV['NATS_URI']]) do
      NATS.request('config.get.redis') do |r|
        return r
      end
    end
  end
end

class API < Sinatra::Base
  configure do
    # Default DB Name
    ENV['DB_URI'] ||= Config.load_db[:url]
    ENV['DB_REDIS'] ||= Config.load_redis
    ENV['DB_NAME'] ||= 'clients'

    #  Initialize database
    Sequel::Model.plugin(:schema)
    DB = Sequel.connect("#{ENV['DB_URI']}/#{ENV['DB_NAME']}")

    # Create users database table if does not exist
    DB.create_table? :clients do
      String :client_id, null: false, primary_key: true
      String :client_name, null: false
      unique [:client_name]
    end

    Object.const_set('ClientModel', Class.new(Sequel::Model(:clients)))
  end

  #  Set content type for the entire API as JSON
  before do
    content_type :json
  end

  # Every call needs to use authorization
  use Authentication

  #  POST /clients
  #  
  #  Create a clients
  #  * Only admin users can create clients
  post '/clients/?' do
    halt 401 unless env[:current_user][:admin]
    client = JSON.parse(request.body.read, symbolize_names: true)
    existing_client = ClientModel.filter(client_name: client[:client_name]).first
    unless existing_client.nil?
      halt 409, url("/clients/#{existing_client[:client_id]}")
    end
    client[:client_id] = SecureRandom.uuid
    ClientModel.insert(client)
    client.to_json
  end

  #  GET /clients
  #
  #  Fetch all clients
  #  * Only admin users can get a list of clients
  get '/clients/?' do
    halt 401 unless env[:current_user][:admin]
    ClientModel.all.map(&:to_hash).to_json
  end

  #  GET /clients/:client
  #
  # Fetch a client byt its ID
  # * Admin users can get information of any client
  # * Non-Admin users only can get information about himselfs
  get '/clients/:client/?' do
    if env[:current_user][:admin]
      client = ClientModel.filter(client_id: params[:client]).first
      halt 404 if client.nil?
      client.to_hash.to_json
    elsif params[:client] == env[:current_user][:client_id]
      client = ClientModel.filter(client_id: env[:current_user][:client_id]).first
      client.to_hash.to_json
    else
      halt 401
    end
  end

  #  PUT /clients/:client
  #
  #  Updates a client by its ID
  put '/clients/:client/?' do
    halt 405
  end

  #  DELETE /clients/:client
  #
  #  Deletes an client by its ID
  #  * ONly admin users can delete a client
  delete '/clients/:client/?' do
    if env[:current_user][:admin]
      client = ClientModel.filter(client_id: params[:client]).first
      halt 404 if client.nil?
      client.delete
      status 200
    elsif params[:client] == env[:current_user][:client_id]
      client = ClientModel.filter(client_id: env[:current_user][:client_id]).first
      client.delete
      status 200
    else
      halt 401
    end
  end
end
