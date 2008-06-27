require 'activerdf'
require 'activerdf.federation.federation_manager'
require 'activerdf.queryengine.query'

local ConnectionPool = activerdf.ConnectionPool
local oo = activerdf.oo
local RDFLite = activerdf_rdflite.RDFLite
local RDFS = activerdf.RDFS
local Query = activerdf.Query
local Namespace = activerdf.Namespace
local table = activerdf.table
local ObjectManager = activerdf.ObjectManager

local TEST_PATH = 'lua/activerdf_rdflite/test/'

local function dotest(test)
	setup()
	test()
	teardown()
end

function setup()
	ConnectionPool.clear()	
end

function teardown()	
end

function test_registration()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	assert ( oo.instanceof ( adapter, RDFLite ) )
end

function test_initialise()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite', keyword = false }
	assert ( not adapter.keyword_search ) 
end

function test_duplicate_registration()
	local adapter1 = ConnectionPool.add_data_source { type = 'rdflite' }
	local adapter2 = ConnectionPool.add_data_source { type = 'rdflite' }	
	assert ( adapter1 == adapter2 )	
end

function test_simple_query()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	
	local eyal = RDFS.Resource ( 'eyaloren.org' )
	local age = RDFS.Resource ( 'foaf:age' )
	local test = RDFS.Resource ( 'test' )
	
	adapter:add(eyal, age, test)
	
	local result = Query():distinct('?s'):where('?s', '?p', '?o'):execute { flatten = true }
	assert ( oo.instanceof ( result, RDFS.Resource ) )
	assert ( 'eyaloren.org' == result.uri )
end

function test_escaped_literals()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	local eyal = RDFS.Resource ( 'eyal' )
	local comment = RDFS.Resource ( 'comment' )
	local string = [[test\nbreak"quoted"]]
	local interpreted = [[test\nbreak"quoted"]]
	
	adapter:add(eyal, comment, string)
	assert ( interpreted == eyal.comment )
	
	local description = RDFS.Resource ( 'description' )
	local string = 'ümlaut and \u00ebmlaut'
	local interpreted = "ümlaut and ëmlaut"
	
	adapter:add(eyal, description, string)
	assert ( interpreted == eyal.description )
end

function test_load_escaped_literals()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_escaped_data.nt')
	local eyal = RDFS.Resource ( 'http://activerdf.org/test/eyal' )
	
	assert ( 2 == adapter:size() )
	assert ( "ümlauts and ëmlauts" == eyal.comment )
	assert ( "line\nbreaks, <p>'s and \"quotes\"" == eyal.encoded )
end

function test_federated_query()
    local adapter1 = ConnectionPool.add_data_source { type = 'rdflite' }
    local adapter2 = ConnectionPool.add_data_source { type = 'rdflite', fake_symbol_to_get_unique_adapter = true }

    local eyal = RDFS.Resource ( 'eyaloren.org' )
    local age = RDFS.Resource ( 'foaf:age' )
    local test = RDFS.Resource ( 'test' )
    local test2 = RDFS.Resource ( 'test2' )

    adapter1:add(eyal, age, test)
    adapter2:add(eyal, age, test2)

    -- assert only one distinct subject is found (same one in both adapters)
    assert ( 1, table.getn ( Query():distinct('?s'):where('?s', '?p', '?o'):execute() ) )

    -- assert two distinct objects are found
    local results = Query():distinct('?o'):where('?s', '?p', '?o'):execute()
    assert ( 2 == table.getn( results ) )

	table.all ( results, function (i, result) assert ( oo.instanceof ( result, RDFS.Resource) ) end )
end

function test_query_with_block()
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }

    local eyal = RDFS.Resource ( 'eyaloren.org' )
    local age = RDFS.Resource ( 'foaf:age' )
    local test = RDFS.Resource ( 'test' )

    adapter:add(eyal, age, test)
    Query():select('?s','?p'):where('?s','?p','?o'):execute ( { flatten = false } , function (s,p)      
      assert ( 'eyaloren.org' == s.uri )
      assert ( 'foaf:age' == p.uri )
    end)
end

function test_loading_data()
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')
	assert ( 32 == adapter:size() )

    adapter:clear()
    adapter:load('http://www.w3.org/2000/10/rdf-tests/rdfcore/ntriples/test.nt')
    assert ( 30 == adapter:size() )

    adapter:clear()
    adapter:load('http://www.w3.org/2000/10/rdf-tests/rdfcore/testSchema.rdf')
    assert ( 76 == adapter:size() )
end

function test_load_bnodes()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_bnode_data.nt')
	
	-- loaded five triples in total
	assert ( 5 == adapter:size() )
	
	-- triples contain two distinct bnodes
	assert ( 2 == Query():count():distinct('?s'):where('?s','?p','?o'):execute() )
	
	-- collecting the bnodes
	local bnodes = Query():distinct('?s'):where('?s','?p','?o'):execute()
	-- assert that _:#1 occurs in three triples
	assert ( 3 == table.getn( Query():select('?p','?o'):where(bnodes[1], '?p', '?o'):execute() ) )
	-- assert that _:#2 occurs in two triples
	assert ( 2 == table.getn ( Query():select('?p','?o'):where(bnodes[2], '?p', '?o'):execute() ) ) 
end

function test_count_query()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')
	-- assert_kind_of Fixnum, Query.new.count(:s).where(:s,:p,:o).execute
	assert ( type ( Query():count('?s'):where('?s','?p','?o'):execute() ) == 'number' )
	assert ( 32 == Query():count('?s'):where('?s','?p','?o'):execute() )
end

function test_single_context()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	local file = TEST_PATH..'test_data.nt'
	adapter:load(file)

	local context = Query():distinct('?c'):where('?s','?p','?o','?c'):execute { flatten = true }
	assert ( oo.instanceof ( context, RDFS.Resource ) ) 
	assert ( RDFS.Resource("file:"..file) == context )
end

function test_multiple_context()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	local file = TEST_PATH..'test_data.nt'
	adapter:load(file)
	local file_context = RDFS.Resource("file:"..file) 
	
	local eyal = RDFS.Resource ( 'eyaloren.org' )
	local age = RDFS.Resource ( 'foaf:age' )
	local test = RDFS.Resource ( 'test' )
	adapter:add(eyal, age, test, 'context')

	local context = Query():distinct('?c'):where('?s','?p','?o','?c'):execute()
			  
	assert ( file_context == context[1] )
	assert ( 'context' == context[2] )

	assert ( 10 == Query():count():distinct('?s'):where('?s', '?p', '?o', nil):execute() )
	assert ( 1 == Query():count():distinct('?s'):where('?s', '?p', '?o', 'context'):execute() )
	assert ( 9 == Query():count():distinct('?s'):where('?s', '?p', '?o', file_context):execute() )
end

function test_person_data() 
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')

    Namespace.register('test', 'http://activerdf.org/test/')
    local eyal = Namespace.lookup('test', 'eyal')
    local eye = Namespace.lookup('test', 'eye')
    local person = Namespace.lookup('test', 'Person')
    local _type = Namespace.lookup('rdf', 'type')
    local resource = Namespace.lookup('rdfs', 'resource')

    local color = Query():select('?o'):where(eyal, eye,'?o'):execute { flatten =  true }
    assert ( 'blue' == color )
    assert ( type ( color ) == 'string' )

    ObjectManager.construct_classes()
    assert ( oo.instanceof ( eyal, activerdf.TEST.Person ) )
    assert ( oo.instanceof ( eyal, RDFS.Resource ) )
end

function test_delete_data()
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')
	assert ( 32 == adapter:size() )

    local eyal = RDFS.Resource('http://activerdf.org/test/eyal')
	adapter:delete(eyal, nil, nil)
	assert ( 27 == adapter:size() )

	adapter:delete(nil, nil, nil)
	assert ( 0 == adapter:size() )
end

function test_keyword_search()
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')

    local eyal = RDFS.Resource ('http://activerdf.org/test/eyal')
    
    -- we cant garantuee that ferret is installed
    if adapter.keyword_search then
  		assert ( eyal == Query():distinct('?s'):where('?s','?keyword',"blue"):execute { flatten = true } )
  		assert ( eyal == Query():distinct('?s'):where('?s','?keyword',"27"):execute { flatten = true } )
  		assert ( eyal == Query():distinct('?s'):where('?s','?keyword',"eyal oren"):execute { flatten = true } )
	end
end

function test_bnodes()
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')

    Namespace.register('test', 'http://activerdf.org/test/')
    ObjectManager.construct_classes()
    assert ( 2 == table.getn ( activerdf.TEST.Person:find_all() ) )
	assert ( 29 == tonumber ( activerdf.TEST.Person:find_all()[2].age ) )
	assert ( "Another Person" == activerdf.TEST.Person:find_all()[2].name )
end

function test_multi_join()
	local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	local type = Namespace.lookup('rdf', 'type')
	local transProp = Namespace.lookup('owl', 'TransitiveProperty')
	
	Namespace.register('test', 'http://test.com/')
	local ancestor = Namespace.lookup('test', 'ancestor')
	local sue = Namespace.lookup('test', 'Sue')
	local mary = Namespace.lookup('test', 'Mary')
	local anne = Namespace.lookup('test', 'Anne')
	
	adapter:add ( ancestor, type, transProp )
	adapter:add ( sue, ancestor, mary )
	adapter:add ( mary, ancestor, anne )
	
	-- test that query with multi-join (joining over 1.p==2.p and 1.o==2.s) works
	local query = Query():select('?Sue', '?p', '?Anne')
	query:where('?p', type, transProp)
	query:where('?Sue', '?p', '?Mary')
	query:where('?Mary', '?p', '?Anne')
	assert ( 1 == table.getn ( query:execute() ) )
end

function test_limit_and_offset()
    local adapter = ConnectionPool.add_data_source { type = 'rdflite' }
	adapter:load(TEST_PATH..'test_data.nt')
    Namespace.register('test', 'http://activerdf.org/test/')
    local TEST = activerdf.TEST

    --assert ( 7 == table.getn ( RDFS.Resource:find('?all') ) ) 
    --assert ( 5 == table.getn ( RDFS.Resource:find('?all', { limit = 5 } ) ) )
    --assert ( 4 == table.getn ( RDFS.Resource:find('?all', { limit = 4, offset = 3 } ) ) )
    --assert ( RDFS.Resource:find( '?all', { limit = 4, offset = 3 } ) ~= RDFS.Resource:find ( '?all', { limit = 4 } ) )	
	
	assert ( table.equals ( { TEST.eyal, TEST.age, TEST.car } , RDFS.Resource:find( '?all', { limit = 3, order = activerdf.RDF.type } ) ) )
end

dotest(test_bnodes)
dotest(test_count_query)
dotest(test_delete_data)
dotest(test_duplicate_registration)
-- dotest(test_escaped_literals)
dotest(test_federated_query)
dotest(test_initialise)
dotest(test_keyword_search)
dotest(test_limit_and_offset)
dotest(test_load_bnodes)
-- dotest(test_load_escaped_literals)
-- dotest(test_loading_data)
dotest(test_multi_join)
dotest(test_multiple_context)
--dotest(test_person_data) 
dotest(test_query_with_block)
dotest(test_registration)
dotest(test_simple_query)
--dotest(test_single_context)