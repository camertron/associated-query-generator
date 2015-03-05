require 'active_record'
require 'mysql2'

require_relative 'associated_query_generator'

ActiveRecord::Base.establish_connection(
  host: 'localhost',
  username: 'root',
  password: 'password',
  port: 3306,
  database: 'lumos_development',
  adapter: 'mysql2'
)

AssociatedQueryGenerator.queries_for_associated_records('users').each do |query|
  puts query.where(users: { id: 1 }).to_sql
end
