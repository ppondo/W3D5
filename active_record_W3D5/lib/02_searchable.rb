require_relative 'db_connection'
require_relative '01_sql_object'
require 'byebug'

module Searchable
  def where(params)
    where_line = params.keys.map { |k| "#{k} = ?" }
    w = where_line.join(" AND ")
    vals = params.values
    
    data = DBConnection.execute(<<-SQL, *vals)
      SELECT 
        *
      FROM
        #{self.table_name}
      WHERE
        #{w}
    SQL

    data.map { |datum| self.new(datum) }
  end
end

class SQLObject
  extend Searchable
end
