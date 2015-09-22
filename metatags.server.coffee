Xml = require 'xml'

# title, description, image, url
exports.fromHtml = (html) ->
	tree = Xml.decode(html)
	result = {}
	
	if head = Xml.search(tree, '*. head')[0]

		if meta = Xml.search(head, '*.', {tag:'title'})[0]
			result.title = meta.innerText

		if meta = Xml.search(head, '*.', {tag:'link',rel:'image_src'})[0]
			result.image = meta.href

		if meta = Xml.search(head, '*.', {tag:'meta',name:'description'})[0]
			result.description = meta.content

		for meta in Xml.search(head, '*.', {tag:'meta',property:/^og:/})
			result[meta.property.substr(3)] = meta.value || meta.content

	result

