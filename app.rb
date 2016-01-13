require 'sinatra'
require 'amazon/ecs'
if development?
  require 'sinatra/reloader'
  require 'dotenv'
  Dotenv.load
end

class AmazonError < StandardError;end

before do
  Amazon::Ecs.configure do |options|
    options[:AWS_access_key_id] = ENV['PAA_AWS_ID']
    options[:AWS_secret_key]    = ENV['PAA_AWS_SECRET']
    options[:associate_tag]     = ENV['ASSOCIATE_TAG']
    options[:response_group]    = 'Medium'
  end
end

helpers do
  def lookup(asin)
    begin
      response = Amazon::Ecs.item_lookup(asin, country: 'jp') 
      raise AmazonError if response.has_error?
    rescue Amazon::RequestError => e
      puts e
      puts "Retry request to amazon"
      sleep 1.0
      retry
    else
      return response.first_item
    end
  end

  def search(keyword, search_index = 'All', page = 1)
    begin
      response = Amazon::Ecs.item_search(keyword,
                                         search_index: search_index,
                                         item_page: page,
                                         country: 'jp')
      raise AmazonError if response.has_error?
    rescue Amazon::RequestError => e
      puts e
      puts "Retry request to amazon"
      sleep 1.0
      retry
    else
      return response
    end
  end

  def amazon_url(asin, associate_tag)
   "http://www.amazon.co.jp/exec/obidos/ASIN/#{asin}/#{associate_tag}" 
  end
end

%w(/ /search /search/?).each do |path|
  get path do
    slim :index
  end
end

get '/style.css' do
  scss :style
end

get '/search/:keyword' do
  keyword = params[:keyword]
  search_index = params[:search_index] || 'All'
  page = params[:page] || 1

  res = search(keyword, search_index, page)

  @items = res.items
  @total_resulsts = res.total_results
  @total_pages = res.total_pages
  @page = page
  
  if request.xhr?
    slim :search_result, layout: false
  else
    slim :search
  end
end

get '/asin/:asin' do
  halt 400, 'エラー!ASINは10桁の番号です' if params[:asin].size != 10
  @item = lookup(params[:asin])
  @url = amazon_url(params[:asin], ENV['ASSOCIATE_TAG'])
  slim :asin
end
