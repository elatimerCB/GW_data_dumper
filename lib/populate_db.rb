require 'populate_db/version'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'tiny_tds'

module PopulateDb

  def self.execute_sequel(sql_query)
    client = TinyTds::Client.new #[add server config here]
    client.active?
    results = client.execute(sql_query)
    puts "-----------------------"
    puts "#{results.insert}"
    results.cancel
    client.close
  end

  def self.https_requests(url_request)
    uri = URI.parse(url_request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.request(Net::HTTP::Get.new(uri.request_uri))
  end

  def self.create_insert(hash_of_recipe)
    sql_query = 'INSERT into Recipes_test (Output_Item_id, Output_Item_Count, Min_Rating, Disciplines, Ingredients, ID, Type) VALUES '
    hash_of_recipe.each do |recipe|
      sql_query << PopulateDb.format_insertion(recipe)
    end
    sql_query.chop
  end

  def self.format_insertion(values)
    "(
      #{values['output_item_id']},
      #{values['output_item_count']},
      #{values['min_rating']},
      '#{values['disciplines']}',
      '#{values['ingredients']}',
      #{values['id']},
      '#{values['type']}'
    ),"
  end

  def self.recipe_dump(url_request)
    response = PopulateDb.https_requests(url_request)
    list = response.body.gsub('[', '').chomp(']')
    i = 0
    string_of_ids = 'https://api.guildwars2.com/v2/recipes?ids='
    list.split(',').each do |item_id|
      string_of_ids << "#{item_id}"
      if i != 199
        string_of_ids << ','
        i += 1
      else
        results = JSON.parse(PopulateDb.https_requests(string_of_ids).body)
        query = create_insert(results)
        PopulateDb.execute_sequel(query)
        string_of_ids = 'https://api.guildwars2.com/v2/recipes?ids='
        i = 0
      end
    end
    results = JSON.parse(PopulateDb.https_requests(string_of_ids).body)
    query = create_insert(results)
    PopulateDb.execute_sequel(query)
    puts "Be DONE!"
  end

  def self.item_dump(url_request)
    resp = Net::HTTP.get_response(URI.parse(url_request))
    data = resp.body
    converted = JSON.parse(data)
    i = 0
    PopulateDb.execute_sequel('TRUNCATE table Test_Dump')
    sql_query = 'INSERT into Test_Dump (data_id, name) VALUES '
    converted['results'].each do |item|
      if i != 999
        convert_name = item['name'].gsub(/'/, '#')
        sql_query << "(#{item['data_id']}, '#{convert_name}'), "
        i += 1
      else
        convert_name = item['name'].gsub(/'/, '#')
        sql_query << "(#{item['data_id']}, '#{convert_name}')"
        PopulateDb.execute_sequel(sql_query)
        i = 0
        sql_query = 'INSERT into Test_Dump (data_id, name) VALUES '
      end
    end
    sql_query = sql_query.chop.chop
    PopulateDb.execute_sequel(sql_query)
  end
end
