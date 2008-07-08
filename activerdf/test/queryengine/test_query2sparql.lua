require 'activerdf'
require 'activerdf.queryengine.query2sparql'
require 'activerdf.test.common'

local Query = activerdf.Query
local RDFS = activerdf.RDFS
local Query2SPARQL = activerdf.Query2SPARQL

-- TestQuery2Sparql

function test_sparql_generation()
    -- TODO: write tests for distinct, ask

    local query = Query()
    query:select('?s')
    query:where('?s', RDFS.Resource('predicate'), 30)

    local generated = Query2SPARQL.translate(query)
    local expected = "SELECT ?s WHERE { ?s <predicate> \"30\"^^<http://www.w3.org/2001/XMLSchema#integer> . } "
    
    assert ( expected == generated )

    query = Query()
    query:select('?s')
    query:where('?s', RDFS.Resource('foaf:age'), '?a')
    query:where('?a', RDFS.Resource('rdf:type'), RDFS.Resource('xsd:int'))
    generated = Query2SPARQL.translate(query)
    expected = "SELECT ?s WHERE { ?s <foaf:age> ?a . ?a <rdf:type> <xsd:int> . } "
	assert ( expected, generated )
end

function test_sparql_distinct()
    local query = Query()
    query:distinct('?s')
    query:where('?s', RDFS.Resource('foaf:age'), '?a')
    local generated = Query2SPARQL.translate(query)
    local expected = "SELECT DISTINCT ?s WHERE { ?s <foaf:age> ?a . } "
	assert ( expected == generated ) 
end

function test_query_omnipotent()
    -- can define multiple select clauses at once or separately
    local q1 = Query():select('?s','?a')
    local q2 = Query():select('?s'):select('?a')
    assert ( Query2SPARQL.translate(q1), Query2SPARQL.translate(q2) )
end

test_query_omnipotent()
test_sparql_distinct()
test_sparql_generation()