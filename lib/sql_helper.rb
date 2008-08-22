module Sql

  # Combine multiple SQL conditions with 'AND' or 'OR'

  def self.combine(comb, *conds) #:nodoc:
    conds.compact!
    return nil if conds.empty?
    return conds.first if conds.size == 1
    res = [""]
    conds.each do |cond|
      cond = Array(cond)
      res.first << " #{comb} " unless res.first.empty?
      res.first << "(#{cond.first})"
      res += cond[1..-1]
    end
    res
  end

  # Combine one or more conditions with AND
  #
  #   Sql.and(["foo=?", 9], ["bar IS NULL"], ["baz in (?,?)", 123, 456])
  #   => ["(foo=?) AND (bar IS NULL) AND (baz in (?,?))", 9, 123, 456]
  #
  # nil arguments are ignored.
  # Returns nil if there are no arguments, or they are all nil.

  def self.and(*conds)
    combine("AND", *conds)
  end

  # Combine one or more conditions with OR

  def self.or(*conds)
    combine("OR", *conds)
  end

  # Negate a condition
  #
  #    Sql.not("foo=bar")  # => ["NOT (foo=bar)"]

  def self.not(cond)
    cond = Array(cond).dup
    cond[0] = "NOT (#{cond[0]})"
    cond
  end

  # Create a find condition to match any value in an array. Depending
  # on whether the array contains any nil values, the result may be:
  #    ["col IN (?,?,?)", ...]
  #    ["col IN (?,?,?) OR col IS NULL", ...]
  #    ["col IS NULL"]
  #
  # Returns nil a non-array is passed or the array is empty.

  def self.in?(col, values)
    return nil if !values.kind_of?(Array) || values.empty?
    sql = ["#{col} IN ("]
    null = false
    values.each do |v|
      case v
      when nil, ""
        null = true
      else
        sql.first << "?,"
        sql << v
      end
    end
    sql.first[-1] = ?)
    if !null
      # do nothing
    elsif sql.size > 1
      sql.first << " OR #{col} IS NULL"
    else
      sql = ["#{col} IS NULL"]
    end
    sql
  end

  # Create a find condition to match any value in an array, raising
  # an exception if a non-array or empty array is passed.

  def self.in(col, values)
    in?(col, values) || (raise ArgumentError)
  end

  # Create a sql condition to match the given value, or return
  # nil if the value itself is nil or empty string.
  #
  #   Sql.eq?("foo", 123) # => ["foo=?", 123]
  #   Sql.eq?("foo", nil) # => nil
  #   Sql.eq?("foo", "")  # => nil

  def self.eq?(col, value)
    case value
    when nil, ""
      nil
    else
      ["#{col}=?", value]
    end
  end

  # Create a sql condition to match the given value. nil or empty
  # string explicitly test for IS NULL in the database.
  #
  #   Sql.eq("foo", 123) # => ["foo=?", 123]
  #   Sql.eq("foo", nil) # => ["foo IS NULL"]
  #   Sql.eq("foo", "")  # => ["foo IS NULL"]

  def self.eq(col, value)
    eq?(col, value) || ["#{col} IS NULL"]
  end

  # Create a sql condition to check that the col is not equal
  # to the given value, or return nil if the value itself is nil
  # or empty string.
  #
  #   Sql.ne?("foo", 123) # => ["foo!=? OR foo IS NULL", 123]
  #   Sql.ne?("foo", nil) # => nil
  #   Sql.ne?("foo", "")  # => nil

  def self.ne?(col, value)
    case value
    when nil, ""
      nil
    else
      ["#{col}!=? OR #{col} IS NULL", value]
    end
  end

  # Create a sql condition to check the value is different to
  # the one given. nil or empty string explicitly test for IS NOT NULL
  # in the database.
  #
  #   Sql.ne("foo", 123) # => ["foo!=? OR foo IS NULL", 123]
  #   Sql.ne("foo", nil) # => ["foo IS NOT NULL"]
  #   Sql.ne("foo", "")  # => ["foo IS NOT NULL"]

  def self.ne(col, value)
    ne?(col, value) || ["#{col} IS NOT NULL"]
  end

  # Return a 'LIKE' condition if the value contains % or _,
  # or a standard equality, or nil if the value is nil or empty string.
  #
  #   Sql.like?("foo", "b%")  #=> ["foo LIKE ?", "b%"]
  #   Sql.like?("foo", "abc") #=> ["foo=?", "abc"]
  #   Sql.like?("foo", nil)   #=> nil

  def self.like?(col, value)
    case value
    when /[%_]/
      ["#{col} LIKE ?", value]
    else
      eq?(col, value)
    end
  end

  # Return a 'LIKE' condition if the value contains % or _, or
  # otherwise returns an equality test
  #
  #   Sql.like("foo", "b%")  #=> ["foo LIKE ?", "b%"]
  #   Sql.like("foo", "abc") #=> ["foo=?", abc]
  #   Sql.like("foo", nil)   #=> ["foo IS NULL"]

  def self.like(col, value)
    like?(col, value) || ["#{col} IS NULL"]
  end

  # SQL equality condition for IP addresses or subnets. For example,
  # searching for 192.0.2.123 will match
  # * 192.0.2.123
  # * 192.0.2.123/32
  # * 192.0.2.120/30
  # * 192.0.2.120/29
  # * 192.0.2.112/28
  # * 192.0.2.96/27
  # * 192.0.2.64/26
  # * 192.0.2.0/25
  # * 192.0.2.0/24
  # and searching for 192.168.0.96/27 will match all IPs from
  # 192.168.0.96 to 192.168.0.127 inclusive.
  #
  # This only works for prefixes between /24 and /30.
  #
  # Returns nil if value doesn't look like an IP address, so you can
  # choose your own fallback strategy.

  def self.find_ip?(col, value)
    case value

    when /\A\d+\.\d+\.\d+\.\d+\z/  # IP address
      require 'ipaddr'
      sql = ["#{col} IN (?,?", value, "#{value}/32"]
      addr = IPAddr.new(value)
      (24..30).each do |pfx|
         sql.first << ",?"
         sql << "#{addr.mask(pfx).to_s}/#{pfx}"
      end
      sql.first << ")"
      return sql

    when /\A((\d+\.\d+\.\d+)\.\d+)\/(\d+)\z/  # IP network
      require 'ipaddr'
      addr, addr24, pfx = $1, $2, $3.to_i
      case pfx
      when 24
        return ["#{col} LIKE ?", addr24 + ".%"]

      when (25..31)
        sql = ["#{col} IN (?", value]
        a1 = IPAddr.new(value).to_i
        a2 = a1 + (1 << (32 - pfx))
        (a1...a2).each do |a|
          sql.first << ",?"
          sql << IPAddr.new(a, Socket::AF_INET).to_s
        end
        sql.first << ")"
        return sql
        
      when 32
        return ["#{col} IN (?,?)", value, addr]
      end

    end

    # If it's not an IP address we can expand, return nil
    nil
  end

  # General wrapper interface.
  # * If value is an Array, turn it into an IN condition
  # * If value looks like an IP address or subnet, expand it as such.
  # * If value contains % or _, turn it into a LIKE condition
  # * If value is nil or "", return an IS NULL condition
  # * Otherwise, make an equality condition
  #
  # Examples:
  #   Sql.find("foo", 123)    # => ["foo=?", 123]
  #   Sql.find("foo", "bar%") # => ["foo LIKE ?", "bar%"]
  #   Sql.find("foo", nil)    # => ["foo IS NULL"]
  #   Sql.find("foo", "")     # => ["foo IS NULL"]
  #   Sql.find("foo", [1, 2]) # => ["foo IN (?,?)", 1, 2]
  #   Sql.find("foo", "192.0.2.123")
  #   # => ["foo IN (?,?,?,?,?,?,?,?,?)",
  #         "192.0.2.123",    "192.0.2.123/32", "192.0.2.120/30",
  #         "192.0.2.120/29", "192.0.2.112/28", "192.0.2.96/27",
  #         "192.0.2.64/26",  "192.0.2.0/25",   "192.0.2.0/24"]

  def self.find(col, value)
    in?(col, value) || find_ip?(col, value) || like(col, value)
  end

  # Returns a sql condition like find(), except returns nil if the
  # value is nil or empty string. This is useful for building
  # queries where parts are optional:
  #
  #   @customers = Customer.find(:all, :conditions => Sql.and(
  #           Sql.find?("name", params[:name]),
  #           Sql.find?("postcode", params[:postcode]),
  #           Sql.find?("ip", params[:ip])
  #   ))

  def self.find?(col, value)
    in?(col, value) || find_ip?(col, value) || like?(col, value)
  end
end
