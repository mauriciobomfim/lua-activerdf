module "activerdf"

BNode = oo.class({}, RDFS.Resource)

function BNode:__tostring()
	return '<_:'..self.uri..'>'
end