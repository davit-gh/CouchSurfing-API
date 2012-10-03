#!/usr/bin/env ruby
#encoding: utf-8

=begin

Licensed under The MIT License
Copyright (c) 2012 Partido Surrealista Mexicano  
=end

require_relative 'csapi/version'
require 'httparty'
require 'nokogiri'
require 'json'

module CS

  class Api
    include HTTParty
    base_uri 'https://api.couchsurfing.org'
    headers "Content-Type" => 'application/json'
    follow_redirects false
    @uid = '0'
  
  
    def initialize(username, password)
      @username = username;
      r = self.class.post('/sessions', body:{username:username, password:password}.to_json)
      raise CS::AuthError.new("Could not login") if r.code != 200
      @cookies = []
      r.headers['Set-Cookie'].split(/, (?!\d)/).each do |cookie|;
        key,value = cookie.split(';')[0].split('=')
        @cookies = "#{key}=#{value}";
      end
      data = JSON.parse r.body
      @uid = data['url'].gsub(/[^\d]/, '')
      @profile = data.keep_if {|k,v| ['realname','username','profile_image','gender','address'].include?(k)}   
      @profile['uid'] = @uid
      self.class.headers 'Cookie' => @cookies
      @@instance = self
    end


    def Api::instance
      @@instance
    end
  
  
    def requests(limit=10, options)
      url = "/users/#{@uid}/couchrequests"
      q = {
        limit: limit
      }.merge(options)
      r = self.class.get(url,query:q)
      requests = {}
      response = JSON.parse r.body
      response['object'].each do |req|
        key = req.gsub(/[^\d]/, '')
        requests[key] = self.request(key)
      end
      requests
    end
  
  
    def search()
      url = "/search"
      r = self.class.post(url)
      JSON.parse r.body
    end  
  
  
    def request(id)
      url = "/couchrequests/#{id}"
      r = self.class.get(url)
      JSON.parse r.body
    end
  
  
    def userdata
      @profile
    end
  
  
    def profile(user=@uid)
      url = "/users/#{user}"
      r = self.class.get(url)
      JSON.parse r.body
    end
  
  
    def photos(user=@uid)
      url = "/users/#{user}/photos"
      r = self.class.get(url)
      JSON.parse r.body
    end
  
  
    def friends(user=@uid)
      url = "/users/#{user}/friends"
      r = self.class.get(url)
      JSON.parse r.body
    end
  
  
    def references(user=@uid)
      url = "/users/#{user}/references"
      r = self.class.get(url)
      JSON.parse r.body
    end
  
  
  end
  
  class HTTPRequest
    @api = nil
    
    def initialize(options={})
      api = nil
      if options[:username] && options[:password]
        api = CS::Api.new(options[:username], options[:password])
        options.del(:username)
        options.del(:password)
      else
        api = CS::Api::instance
        if api==nil
          raise CS::APIError('You have not authenticated with the service or did not provide a :username and :password')
        end
      end
      
      #pp api.userdata
      options[:subject] = options[:subject] || "#{api.userdata['realname']} from #{api.userdata['address']['country']} sent you a new CouchRequest!"
      options[:number] = options[:number] || 1
      options[:arrival_flexible] = options[:arrival_flexible] || false
      options[:departure_flexible] = options[:departure_flexible] || false
      options[:is_open_couchrequest] = options[:is_open_couchrequest] || false
      options[:from] = api.userdata['uid']
      options[:to] = options[:to] || api.userdata['uid']
      options[:arrival] = Time.at(options[:arrival]).strftime("%FT%TZ") || (Time.now()+86400).strftime("%FT%TZ")
      options[:departure] = Time.at(options[:departure]).strftime("%FT%TZ") || (Time.now()+86400*3).strftime("%FT%TZ")
      options[:message] = options[:message] || "I'm to lazy to write a proper couch request. HOST ME PLZ?"
      #puts options.to_json
      
      url = "/couchrequests"
      response = api.post(url, body:options.to_json)
      
      #pp response.code
      #pp response.body
      
    end
  end
  
  class AuthError < StandardError
  end
  
  class APIError < StandardError
  end
  
  
end