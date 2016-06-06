# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require File.expand_path '../spec_helper.rb', __FILE__

describe 'clients_data_microservice' do
  describe 'a non authorized access' do
    describe 'to create a client' do
      it 'should throw a 403' do
        post '/clients'
        expect(last_response.status).to be 403
      end
    end
    describe 'get client list' do
      it 'should throw a 403' do
        get '/clients'
        expect(last_response.status).to be 403
      end
    end
    describe 'get a specific client' do
      it 'should throw a 403' do
        get '/clients/foo'
        expect(last_response.status).to be 403
      end
    end
  end

  describe 'an authorized access' do
    let!(:username)  { 'admin' }
    let!(:password)  { 'password' }
    let!(:client_id) { 'client_id' }
    let!(:admin)     { true }

    before do
      ClientModel.dataset.destroy
      @token = SecureRandom.hex
      AuthCache.set @token, { user_id:   1,
                              client_id: client_id,
                              user_name: username,
                              password:  password,
                              admin:     admin }.to_json
      AuthCache.expire @token, 3600
    end

    describe 'create client' do
      let!(:id) { '100' }
      let!(:name) { 'foo' }
      let!(:data) { { client_id: id, client_name: name }.to_json }
      describe 'as an admin' do
        before do
          post '/clients',
               data,
               'HTTP_X_AUTH_TOKEN' => @token,
               'CONTENT_TYPE' => 'application/json'
        end
        it 'should response with a 200 code' do
          expect(last_response.status).to be 200
        end
        it 'should store the client on database' do
          clients = ClientModel.dataset.filter(client_name: name)
          expect(clients.count).to be 1
        end

        describe 'duplicating clients' do
          before do
            post '/clients',
                 data,
                 'HTTP_X_AUTH_TOKEN' => @token,
                 'CONTENT_TYPE' => 'application/json'
          end
          it 'should response with a 409 code' do
            expect(last_response.status).to be 409
          end
          it 'should not store the user on database' do
            clients = ClientModel.dataset.filter(client_name: name)
            expect(clients.count).to be 1
          end
        end
      end
      describe 'as non admin' do
        let(:admin) { false }
        before do
          post '/clients',
               data,
               'HTTP_X_AUTH_TOKEN' => @token,
               'CONTENT_TYPE' => 'application/json'
        end
        it 'should respond with a 401 status' do
          expect(last_response.status).to be 401
        end
      end
    end

    describe 'list clients' do
      before do
        1.upto(10) do |i|
          client = ClientModel.new
          client.client_name = "client_#{i}"
          client.client_id = i
          client.save
        end
        get '/clients',
            {},
            'HTTP_X_AUTH_TOKEN' => @token,
            'CONTENT_TYPE' => 'application/json'
      end
      describe 'as an admin' do
        it 'should response with a 200 code' do
          expect(last_response.status).to be 200
        end
        it 'should return a list of existing clients' do
          expect(JSON.parse(last_response.body).length).to be(10)
        end
      end
      describe 'as non admin' do
        let(:admin) { false }
        it 'should respond with a 401 status' do
          expect(last_response.status).to be 401
        end
      end
    end

    describe 'get client details' do
      before do
        client = ClientModel.new
        client.client_name = 'foo'
        client.client_id = 'foo'
        client.save
        get '/clients/foo',
            {},
            'HTTP_X_AUTH_TOKEN' => @token,
            'CONTENT_TYPE' => 'application/json'
      end
      describe 'as an admin' do
        it 'should response with a 200 code' do
          expect(last_response.status).to be 200
        end
        it 'should return client details' do
          client = JSON.parse(last_response.body)
          client[:client_name] = 'foo'
          client[:client_id] = 'foo'
        end
      end
      describe 'as non admin' do
        let!(:admin) { false }
        describe 'and client owner' do
          let!(:client_id) { 'foo' }
          it 'should response with a 200 code' do
            expect(last_response.status).to be 200
          end
          it 'should return client details' do
            client = JSON.parse(last_response.body)
            client[:client_name] = 'foo'
            client[:client_id] = 'foo'
          end
        end
        describe 'and the client does not exist' do
          let!(:admin) { true }
          before do
            get '/clients/unexisting',
                {},
                'HTTP_X_AUTH_TOKEN' => @token,
                'CONTENT_TYPE' => 'application/json'
          end
          it 'should response with a 404 code' do
            expect(last_response.status).to be 404
          end
        end
        describe 'and non client owner' do
          it 'should response with a 401 code' do
            expect(last_response.status).to be 401
          end
        end
      end
    end

    describe 'update clients' do
      before do
        put '/clients/foo',
            '',
            'HTTP_X_AUTH_TOKEN' => @token,
            'CONTENT_TYPE' => 'application/json'
      end
      it 'should return a Not Implemented response' do
        expect(last_response.status).to be(405)
      end
    end

    describe 'delete clients' do
      describe 'delete client details' do
        let!(:client_id) { 'foo' }
        before do
          client = ClientModel.new
          client.client_name = 'foo'
          client.client_id = client_id
          client.save
          delete '/clients/foo',
                 {},
                 'HTTP_X_AUTH_TOKEN' => @token,
                 'CONTENT_TYPE' => 'application/json'
        end
        describe 'as an admin' do
          it 'should response with a 200 code' do
            expect(last_response.status).to be 200
          end
          it 'should unpersist the client' do
            expect(ClientModel.filter(client_id: client_id).count).to be(0)
          end
        end
        describe 'as non admin' do
          let!(:admin) { false }
          describe 'and client owner' do
            let!(:client_id) { 'foo' }
            it 'should response with a 200 code' do
              expect(last_response.status).to be 200
            end
            it 'should unpersist the client' do
              expect(ClientModel.filter(client_id: client_id).count).to be(0)
            end
          end
          describe 'and the client does not exist' do
            let!(:admin) { true }
            before do
              get '/clients/unexisting',
                  {},
                  'HTTP_X_AUTH_TOKEN' => @token,
                  'CONTENT_TYPE' => 'application/json'
            end
            it 'should response with a 404 code' do
              expect(last_response.status).to be 404
            end
          end
          describe 'and non client owner' do
            let(:client_id) { 'another' }
            it 'should response with a 401 code' do
              expect(last_response.status).to be 401
            end
          end
        end
      end
    end
  end
end
