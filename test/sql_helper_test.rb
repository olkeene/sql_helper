require 'test/unit'
require 'sql_helper'

class SqlHelperTest < Test::Unit::TestCase

  def test_sql_and
    sql1 = 'foo=bar and baz=4'
    sql2 = ['abc in (?,?,?,?)',9,8,7,6]
    sql3 = ['xyz LIKE ? or xyz LIKE ?','aaa%','bbb%']
    assert_equal([
	"(foo=bar and baz=4) AND (abc in (?,?,?,?)) AND (xyz LIKE ? or xyz LIKE ?)",
	9,8,7,6,'aaa%','bbb%',
    ], Sql.and(sql1, sql2, sql3))

    assert_equal(nil, Sql.and())
    assert_equal(nil, Sql.and(nil))
    assert_equal(sql1, Sql.and(sql1))
    assert_equal(sql1, Sql.and(sql1, nil))
  end

  def test_sql_or
    sql1 = ['foo=?', 5]
    sql2 = ['bar=?', 7]
    assert_equal(["(foo=?) OR (bar=?)", 5, 7], Sql.or(sql1, sql2))

    assert_equal(nil, Sql.or())
    assert_equal(nil, Sql.or(nil))
    assert_equal(sql1, Sql.or(sql1))
    assert_equal(sql1, Sql.or(sql1, nil))
  end

  def test_sql_not
    assert_equal(["NOT (foo=bar)"], Sql.not("foo=bar"))
    assert_equal(["NOT (foo=? OR bar=?)", 5, 7],
	Sql.not(["foo=? OR bar=?", 5, 7]))
  end

  def test_sql_in
    assert_equal([
	"foo IN (?,?,?)", 7, 9, 13,
    ], Sql.in(:foo, [7, 9, 13]))

    assert_equal([
        "foo IN (?,?) OR foo IS NULL", 7, 13,
    ], Sql.in(:foo, [7, nil, 13]))

    assert_equal([
        "foo IS NULL",
    ], Sql.in(:foo, [nil]))

    assert_raises(ArgumentError) { Sql.in(:foo, []) }
    assert_raises(ArgumentError) { Sql.in(:foo, nil) }
    assert_raises(ArgumentError) { Sql.in(:foo, "bar") }
  end

  def test_sql_in?
    assert_equal([
	"foo IN (?,?,?)", 7, 9, 13,
    ], Sql.in?(:foo, [7, 9, 13]))

    assert_nil Sql.in?(:foo, [])
    assert_nil Sql.in?(:foo, nil)
    assert_nil Sql.in?(:foo, "bar")
  end

  def test_sql_eq
    assert_equal(["foo=?", 7], Sql.eq(:foo, 7))
    assert_equal(["foo IS NULL"], Sql.eq(:foo, nil))
    assert_equal(["foo IS NULL"], Sql.eq(:foo, ""))
  end

  def test_sql_eq?
    assert_equal(["foo=?", 7], Sql.eq(:foo, 7))
    assert_equal(nil, Sql.eq?(:foo, nil))
    assert_equal(nil, Sql.eq?(:foo, ""))
  end

  def test_sql_ne
    assert_equal(["foo!=? OR foo IS NULL", 7], Sql.ne(:foo, 7))
    assert_equal(["foo IS NOT NULL"], Sql.ne(:foo, nil))
    assert_equal(["foo IS NOT NULL"], Sql.ne(:foo, ""))
  end

  def test_sql_ne?
    assert_equal(["foo!=? OR foo IS NULL", 7], Sql.ne(:foo, 7))
    assert_equal(nil, Sql.ne?(:foo, nil))
    assert_equal(nil, Sql.ne?(:foo, ""))
  end

  def test_sql_like
    assert_equal(['foo LIKE ?','bar%'], Sql.like(:foo, 'bar%'))
    assert_equal(['foo=?','bar'], Sql.like(:foo, 'bar'))
    assert_equal(['foo IS NULL'], Sql.like(:foo, nil))
    assert_equal(['foo IS NULL'], Sql.like(:foo, ""))
  end

  def test_sql_like?
    assert_equal(['foo LIKE ?','bar%'], Sql.like?(:foo, 'bar%'))
    assert_equal(['foo=?','bar'], Sql.like?(:foo, 'bar'))
    assert_equal(nil, Sql.like?(:foo, nil))
    assert_equal(nil, Sql.like?(:foo, ""))
  end

  def test_sql_find_simple
    assert_equal(['foo=?','bar'], Sql.find(:foo, 'bar'))

    assert_equal(['foo LIKE ?','bar%'], Sql.find(:foo, 'bar%'))

    assert_equal(['foo IN (?,?)', 3, 5], Sql.find(:foo, [3,5]))

    assert_equal(['foo IS NULL'], Sql.find(:foo, nil))
    assert_equal(['foo IS NULL'], Sql.find(:foo, ""))
  end

  def test_sql_find?
    assert_equal(['foo=?','bar'], Sql.find?(:foo, 'bar'))

    assert_equal(['foo LIKE ?','bar%'], Sql.find?(:foo, 'bar%'))

    assert_equal(['foo IN (?,?)', 3, 5], Sql.find?(:foo, [3,5]))

    assert_equal(nil, Sql.find?(:foo, nil))
    assert_equal(nil, Sql.find?(:foo, ""))
  end

  def test_sql_find_ip_address
    sql = Sql.find(:foo, '192.0.2.123')
    assert_equal('foo IN (?,?,?,?,?,?,?,?,?)', sql.shift)
    assert_equal([
	'192.0.2.123',
	'192.0.2.123/32',
	'192.0.2.120/30',
	'192.0.2.120/29',
	'192.0.2.112/28',
	'192.0.2.96/27',
	'192.0.2.64/26',
	'192.0.2.0/25',
	'192.0.2.0/24',
    ].sort, sql.sort)
  end

  def test_sql_find_ip_network
    sql = Sql.find(:foo, '192.0.2.120/32')
    assert_equal('foo IN (?,?)', sql.shift)
    assert_equal(['192.0.2.120','192.0.2.120/32'], sql.sort)
    
    sql = Sql.find(:foo, '192.0.2.123/29')
    assert_equal('foo IN (?,?,?,?,?,?,?,?,?)', sql.shift)
    assert_equal([
	'192.0.2.123/29',
	'192.0.2.120',
	'192.0.2.121',
	'192.0.2.122',
	'192.0.2.123',
	'192.0.2.124',
	'192.0.2.125',
	'192.0.2.126',
	'192.0.2.127',
    ].sort, sql.sort)
  end

  def test_sql_find_ip?
    sql = Sql.find_ip?(:foo, '192.0.2.120/32')
    assert_equal('foo IN (?,?)', sql.shift)
    assert_equal(['192.0.2.120','192.0.2.120/32'], sql.sort)

    assert_equal(nil, Sql.find_ip?(:foo, 'bar'))
  end
end
