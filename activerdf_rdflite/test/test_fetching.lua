require 'activerdf'

local ConnectionPool = activerdf.ConnectionPool

local function dotest(test)
	setup()
	test()
	teardown()
end

-- TestFetchingAdapter
function setup()
    ConnectionPool.clear()
    adapter = ConnectionPool.add { type = 'fetching' }
end

function teardown()
end

function test_parse_foaf()    
	adapter:fetch("http://eyaloren.org/foaf.rdf#me")
    assert ( adapter:size() > 0 )
end
  
function test_sioc_schema()
    adapter:fetch("http://rdfs.org/sioc/ns#")
    assert ( 560 == adapter:size() ) 
end
    
function test_foaf_schema()
    adapter:fetch("http://xmlns.com/foaf/0.1/")
    -- foaf contains 563 triples but with two duplicates
    assert ( 561 == adapter:size() )    
end

dotest(test_parse_foaf)
dotest(test_sioc_schema)
dotest(test_foaf_schema)