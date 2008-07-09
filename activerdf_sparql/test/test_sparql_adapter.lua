require 'activerdf'
require 'activerdf.federation.federation_manager'
require 'activerdf.queryengine.query'


local ConnectionPool = activerdf.ConnectionPool
local SparqlAdapter = activerdf_sparql.SparqlAdapter
local RDFS = activerdf.RDFS
local Query = activerdf.Query
local Namespace = activerdf.Namespace
local table = activerdf.table
local oo = activerdf.oo

local function dotest(test)
	setup()
	test()
	teardown()
end

-- TestSparqlAdapter
function setup()
    ConnectionPool.clear()
    adapter = ConnectionPool.add { type = 'sparql', url = 'http://dbpedia.org/sparql', engine = 'virtuoso' }
end

function teardown()
end

function test_registration()
    assert ( oo.instanceof ( adapter, SparqlAdapter ) ) 
end

function test_language()
    local sunset = RDFS.Resource("http://dbpedia.org/resource/77_Sunset_Strip")
    local abstract = RDFS.Resource("http://dbpedia.org/property/abstract")

    local german = Query():distinct('?o'):where(sunset,abstract,'?o'):limit(1):lang('?o','de'):execute()[1]
    local english = Query():distinct('?o'):where(sunset,abstract,'?o'):limit(1):lang('?o','en'):execute()[1]

    assert ( string.find ( english, "^77 Sunset Strip was one of the most popular of the detective series in early television" ) )
    assert ( string.find ( german, "^77 Sunset Strip ist ein Serienklassiker aus den USA um das gleichnamige, in Los Angeles am Sunset Boulevard angesiedelte Detektivbüro" ) )
end

function test_limit_offset()
    local one = Query():select('?s'):where('?s','?p','?o'):limit(10):execute()
    assert ( 10 == table.getn ( one ) )

    table.all ( one, function(i, r)
      return assert ( oo.instanceof ( r, RDFS.Resource ) )
    end)

    local two = Query():select('?s'):where('?s','?p','?o'):limit(10):offset(1):execute()
    assert ( 10 == table.getn ( two ) )
    assert ( one[2] == two[1] )

    local three = Query():select('?s'):where('?s','?p','?o'):limit(10):offset(0):execute()
    assert ( table.equals ( one , three ) )
end

function test_regex_filter()
    Namespace.register ( 'yago', 'http://dbpedia.org/class/yago/' )
    Namespace.register ( 'dbpedia', 'http://dbpedia.org/property/' )

    local movies = Query():select('?title'):where('?film', RDFS.label, '?title'):where('?title', RDFS.Resource('bif:contains'), 'kill'):filter_regex('?title', "Kill$"):execute()

    assert ( not table.empty (movies) , "regex query returns empty results" )
    assert ( table.all ( movies, function(i,m) return string.find( m , "Kill$" ) end ), "regex query returns wrong results" )
end

function test_query_with_block()
    local reached_block = false
    Query():select('?s', '?p'):where('?s','?p','?o'):limit(1):execute(nil, function ( s, p )
      reached_block = true
      assert ( RDFS.Resource == oo.classof(s) )
      assert ( RDFS.Resource == oo.classof(p) )
    end)
    assert ( reached_block, "querying with a block does not work" )

    reached_block = false
    Query():select('?s', '?p'):where('?s','?p','?o'):limit(3):execute(nil, function ( s, p )
      reached_block = true      
      assert ( RDFS.Resource == oo.classof(s) )
      assert ( RDFS.Resource == oo.classof(p) )
    end)
    assert ( reached_block, "querying with a block does not work" )

    reached_block = false
    Query():select('?s'):where('?s','?p','?o'):limit(3):execute({}, function (s)
      reached_block = true      
      assert ( RDFS.Resource == oo.classof(s) )
    end)

    assert ( reached_block, "querying with a block does not work" )
end

function test_refuse_to_write()
    local eyal = RDFS.Resource 'http://activerdf.org/test/eyal'
    local age = RDFS.Resource 'foaf:age'
    local test = RDFS.Resource 'test'

    -- NameError gets thown if the method is unknown
    assert ( not pcall ( adapter.add, eyal, age, test ) )    
end

function test_literal_conversion()
    -- test literal conversion
    local label = Query():distinct('?label'):where('?s', RDFS.label, '?label'):limit(1):execute('flatten')
    assert ( type ( label ) ==  "string" )
end

--dotest(test_language)
dotest(test_limit_offset)
dotest(test_literal_conversion)
dotest(test_query_with_block)
dotest(test_refuse_to_write)
--dotest(test_regex_filter)