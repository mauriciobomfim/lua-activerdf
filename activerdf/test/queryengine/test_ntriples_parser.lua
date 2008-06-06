require 'activerdf'
require 'activerdf.queryengine.ntriples_parser'
require 'activerdf.test.common'

local NTriplesParser = activerdf.NTriplesParser
local table = activerdf.table
local RDFS = activerdf.RDFS

function setup()
end

function teardown()
end

function test_simple_triples()
    local str = [[
<http://www.johnbreslin.com/blog/author/cloud/#foaf> <http://xmlns.com/foaf/0.1/surname> "Breslin" .
<http://www.johnbreslin.com/blog/author/cloud/#foaf> <http://xmlns.com/foaf/0.1/firstName> "John" .
<http://www.johnbreslin.com/blog/author/cloud/> <http://purl.org/dc/terms/created> "1999-11-30T00:00:00" .  				
]]
    
    local triples = NTriplesParser.parse(str)    
    assert ( 9 == table.getn(table.flatten(triples)) )
    assert ( 3 == table.getn(triples[1]) )

    assert ( RDFS.Resource('http://www.johnbreslin.com/blog/author/cloud/#foaf') == triples[1][1] )
    assert ( RDFS.Resource('http://xmlns.com/foaf/0.1/surname') == triples[1][2] )
    assert ( 'Breslin' == triples[1][3] )
end

function test_encoded_content()
    local str = [[
  <http://b4mad.net/datenbrei/archives/2004/07/15/brainstream-his-own-foafing-in-wordpress/#comment-10> <http://purl.org/rss/1.0/modules/content/encoded> "<p>Heh - excellent. Are we leaving Morten in the dust? :) I know he had some bu gs to fix in his version.</p>\n<p>Also, I think we should really add the foaf: in front of the foaf properties to ma ke it easier to read. </p>\n<p>Other hack ideas:</p>\n<p>* Birthdate in month/date/year (seperate fields) to add bio :Event/ bio:Birth and then say who can see the birth year, birth day/mo and full birth date.<br />\n* Add trust leve ls to friends<br />\n* Storing ones PGP key/key fingerprint in Wordpress and referencing it as user_pubkey/user_pubk eyprint respectively<br />\n* Add gender, depiction picture for profile, myers-brigs, astrological sign fields to Pr ofile.<br />\n* Add the option to create Projects/Groups user is involved with re: their Profile.<br />\n* Maybe add phone numbers/address/geo location? Essentially make it a VCard that can be foafified.\n</p>\n" .
]]
    local literal = '<p>Heh - excellent. Are we leaving Morten in the dust? :) I know he had some bu gs to fix in his version.</p>\n<p>Also, I think we should really add the foaf: in front of the foaf properties to ma ke it easier to read. </p>\n<p>Other hack ideas:</p>\n<p>* Birthdate in month/date/year (seperate fields) to add bio :Event/ bio:Birth and then say who can see the birth year, birth day/mo and full birth date.<br />\n* Add trust leve ls to friends<br />\n* Storing ones PGP key/key fingerprint in Wordpress and referencing it as user_pubkey/user_pubk eyprint respectively<br />\n* Add gender, depiction picture for profile, myers-brigs, astrological sign fields to Pr ofile.<br />\n* Add the option to create Projects/Groups user is involved with re: their Profile.<br />\n* Maybe add phone numbers/address/geo location? Essentially make it a VCard that can be foafified.\n</p>\n'					

    local triples = NTriplesParser.parse(str)
    assert ( 1 == table.getn ( triples ) )

    local encoded_content = triples[1][3]    
    assert ( literal == encoded_content )
    assert ( "string" == type(encoded_content) )
    assert ( string.find( encoded_content, 'PGP' ) )
end

function test_escaped_quotes()
	local string = [[<subject> <predicate> "test string with \n breaks and \" escaped quotes" .]]
    local literal = 'test string with \n breaks and \" escaped quotes'
    local triples = NTriplesParser.parse(string)

    assert ( 1 == table.getn( triples ) )
    assert ( literal == triples[1][3] )
end

function test_datatypes()
    local string =[[
<s> <p> "blue" .
<s> <p> "29"^^<http://www.w3.org/2001/XMLSchema#integer> .
<s> <p> "false"^^<http://www.w3.org/2001/XMLSchema#boolean> .
<s> <p> "2002-10-10T00:00:00+13"^^<http://www.w3.org/2001/XMLSchema#date> .
]]
    local triples = NTriplesParser.parse(string)
    assert ( 4 == table.getn ( triples ) )
    assert ( 'blue' == triples[1][3] )
    assert ( 29 == triples[2][3] )    
    assert ( triples[3][3] == false )
    -- assert ( triples[4][3] == DateTime.parse('2002-10-10T00:00:00+13')
end

setup()
test_datatypes()
test_encoded_content()
test_escaped_quotes()
test_simple_triples()
teardown()