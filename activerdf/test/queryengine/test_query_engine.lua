require 'activerdf'
require 'activerdf.queryengine.query'
require 'activerdf.queryengine.query2sparql'
require 'activerdf.test.common'

local RDFS = activerdf.RDFS
local Query2SPARQL = activerdf.Query2SPARQL
local Query = activerdf.Query

-- TestQueryEngine
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
    assert ( expected == generated )

    --		query = Query.new
    --		query.select('?s').select(:a)
    --		query.where('?s', 'foaf:age', :a)
    --		generated = Query2SPARQL.translate(query)
    --		expected = "SELECT DISTINCT ?s ?a WHERE { ?s foaf:age ?a .}"
    --		assert_equal expected, generated
end

function test_query_omnipotent()
    -- can define multiple select clauses at once or separately
    local q1 = Query():select('?s','?a')
    local q2 = Query():select('?s'):select('?a')
    assert ( Query2SPARQL.translate(q1) == Query2SPARQL.translate(q2) )
end

test_query_omnipotent()
test_sparql_generation()