require 'rubygems'
require 'sinatra'
require 'open-uri'
require 'hpricot'

get '/' do
  "Hello from Sinatra on Heroku!"
end

get '/tables/*/:table_number.csv' do
  #puts params[:splat].inspect
  #puts params[:table_number]
  url = params[:splat].first
  data = read_url(url)
  doc = Hpricot(data)
  tables = doc.search('//table')
  table = tables[params[:table_number].to_i]
  table_data, has_header = table_to_rows_and_columns(table)
  response = data_to_csv_format(table_data)

  title = doc.search('//title').inner_text.gsub(/ - Wikipedia, the free encyclopedia/, '').split(" ").join("_") + "_" + params[:table_number]
  content_type 'text/csv'
  attachment("#{title}.csv")
  response
end

get '/tables/*' do
  url = params[:splat].first
  data = read_url(url)
  doc = Hpricot(data)
  tables = doc.search('//table')
  @tables = []
  @table_headers = []
  tables.each do |table|
    table_data, has_header = table_to_rows_and_columns(table)
    next if table_data.size == 0
    @tables << table_data
    @table_headers << has_header
  end
  @title = doc.search('//title').inner_text.gsub(/ - Wikipedia, the free encyclopedia/, '')
  haml :tables
end

def read_url(url)
  raise Exception, "Need a URL" unless url
  url.gsub!(/http:\//, 'http://') unless url.match(/http:\/\//)
  uri = URI.parse(url)
  begin
    data = uri.read
  rescue
    raise Exception, "Error reading URL: #{url}"
  end
  data
end

def data_to_csv_format(rows)
  rows.map do |row|
    row.map{|h| "'#{h.gsub(/\n/, '')}'"}.join(',')
  end.join("\n")
end

def table_to_rows_and_columns(table)
  rows = []
  has_header = false
  column_count = 0
  row_elements = table.search('//tr')
  row_elements.each do |row|
    header_elements = row.search('//th')
    if header_elements.size > 0
      rows << header_elements.map(&:inner_text)
      has_header = true
    end
    
    row_elements = row.search('//td')
    
    #we can't produce a csv if the table has different column counts...
    if column_count == 0
      column_count = row_elements.size
    else
      return [], has_header if row_elements.size != column_count
    end
    
    rows << row_elements.map(&:inner_text)
  end
  
  lines = []
  rows.each do |row|
    next if row.empty?
    lines << row
  end
  return [], has_header if lines.size < 2
  return lines, has_header
end