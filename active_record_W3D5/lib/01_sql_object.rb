require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns unless @columns == nil
    data = DBConnection.execute2(<<-SQL)
      SELECT 
        *
      FROM
        "#{self.table_name}"
    SQL

    @columns = data[0].map! { |cols| cols.to_sym }
  end

  def self.finalize!
    self.columns.each do |col|
      define_method(col) do 
        self.attributes[col]
      end
  
      define_method("#{col}=") do |value|
        self.attributes[col] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
   @table_name ||= "#{self}".tableize
  end

  def self.all
    data = DBConnection.execute(<<-SQL)
      SELECT 
        *
      FROM
        "#{self.table_name}"
    SQL

    self.parse_all(data)
  end

  def self.parse_all(results)
    objects = []
    results.each do |result|
      objects << self.new(result)
    end

    objects
  end

  def self.find(id)
    data = DBConnection.execute(<<-SQL, id)
      SELECT 
        *
      FROM
        "#{self.table_name}"
      WHERE
        id = ?
      LIMIT
        1
    SQL

    unless data == []
      return self.new(data[0])
    else
      return nil
    end
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      sym = attr_name.to_sym
      unless self.class.columns.include?(sym)
        raise "unknown attribute '#{attr_name}'" 
      else
        self.send("#{attr_name}=", value)
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |col|
      self.send("#{col}")
    end
  end

  def insert
    col_names = self.class.columns.drop(1)
    cols = col_names.map(&:to_sym).join(", ")
    vals = self.attribute_values.drop(1)

    q_marks = []
    col_names.length.times { q_marks << "?" }
    q = q_marks.join(", ")
   
    data = DBConnection.execute(<<-SQL, *vals)
      INSERT INTO
        #{self.class.table_name} (#{cols})
      VALUES
        (#{q})
      SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.drop(1)
    cols = col_names.map { |c| "#{c} = ?" }.join(", ")
    vals = self.attribute_values.drop(1)

    data = DBConnection.execute(<<-SQL, *vals)
      UPDATE
        #{self.class.table_name} 
      SET
        #{cols}
      WHERE
        id = (#{self.id})
      SQL
  end

  def save
    data = self.class.find(self.id)

    data == nil ? self.insert : self.update 
  end
end
