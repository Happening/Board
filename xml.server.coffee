# A small and simple XML/HTML parsing and selector library. It can be used in
# any Javascript environment (browser or server-side) and has no dependencies.
#
# It's guaranteed to not-comply with any standards, but should be a good fit
# for most scraping purposes. It handles doctypes, CDATA, comments, HTML
# entities, HTML5 self-closing tags and missing closing tags (to some extend).
#
# Uglified and gzipped, it's only 1.5kb, or 3kb if you include the HTML entity 
# lookup table.


# Copyright (c) 2015, Happening BV (https://happening.im)
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.



# Given an `xml` input string (which is assumed to be encoded in the proper
# UCS-2 Javascript encoding), returns a Javascript data structure that contains
# a rough representation. The focus is on ease of use and implementation,
# instead of correctness. The decoder makes an effort to always deliver a 
# reasonable tree, even when the input data is invalid. Therefore, it should
# be quite suitable for all kinds of scraping.
#
# The `opts.html` flag (`true` by default) causes self-closing HTML tags such
# as `IMG` to be parsed as expected.
#
# Each node in the tree is a Javascript object that has its XML properties 
# mapped to Javascript properties. There are a few special properties:
#  `tag`: XML tag name as a lower case string,
#  `parentNode`: the parent node, set for all nodes but the root node if
#                `opts.parentNode` is true,
#  `children`: an array of nodes and strings (for text nodes), set for all
#              non-self-closing tags, and
#  `innerText`: for convenience, set to the value of the single text-node
#               child; not set if there are multiple children.

exports.decode = (xml, opts={}) ->
	xml = xml.trim()
	topNode = node = {tag: 'document', children: []}
	nodeStack = []
	tagStack = []
	
	while match = tagRe.exec(xml)
		{0:all,1:pre,3:comment,4:cdata,5:tag,6:attrs} = match
		xml = xml.substr all.length
		node.children.push decodeEntities pre if pre
		if cdata?
			node.children.push {tag: 'cdata', data: decodeEntities cdata}
			continue
		if comment?
			node.children.push {tag: 'comment', data: decodeEntities comment}
			continue

		tag = tag.toLowerCase()
		if tag[0]=='/' # close
			tag = tag.substr 1
			# If we find a proper closing tag somewhere in the top 3 items of the stack, apply it!
			for i in [tagStack.length-1..tagStack.length-3] by -1
				if tagStack[i]==tag
					node = nodeStack[i]
					nodeStack.length = tagStack.length = i
					break
		else # open
			close = (opts.html ? true) && selfClosing[tag]
			if attrs[attrs.length-1]=='/'
				close = true
				attrs = attrs.substr 0, attrs.length-1

			newNode = {tag: tag}

			while match = attrRe.exec(attrs)
				{0:all,2:key} = match
				attrs = attrs.substr all.length
				val = match[4] ? match[5] ? match[6]
				if key
					newNode[if key=='class' then 'className' else key] = decodeEntities val
				else if val
					newNode[val] = true

			node.children.push newNode

			unless close
				tagStack.push tag
				nodeStack.push node
				newNode.children = []
				node = newNode

	node.children.push decodeEntities xml if xml

	if topNode.children.length<2
		topNode = topNode.children[0]

	augmentRecursive topNode, opts.parentNode

	topNode


tagRe = /^([\s\S]*?)<(!--([\s\S]*?)--|!\[CDATA\[([\s\S]*?)]]|([^\s<>]+)(([^<>'"]|'[^']*'|"[^"]*")*))>/
attrRe = /^\s*(([^\s=]+)\s*=)?('([^']*)'|"([^"]*)"|(\S+))/


augmentRecursive = (node,parentNode) ->
	children = node.children
	if children.length == 1 and typeof children[0] is 'string'
		node.innerText = children[0]
	else
		for child in children when typeof child is 'object' and child.children
			child.parentNode = node if parentNode
			augmentRecursive child, parentNode
	return


decodeEntities = (string) ->
	string.replace /&#\d+;|&[a-z][a-z0-9]+;/gi, (match) ->
		if match[1]=='#' and ch = 0|match.substr(2,match.length-3)
			String.fromCharCode(ch)
		else
			entities[match.substr(1,match.length-2)] || match



# Search a tree such as returned by `decode` in a way that resembles css
# selectors, but with a different -more powerful- syntax.
#
# In its most basic form `terms` can be an array of functions. When the
# functions match a parent-child chain, the deepest child will be part of
# the result array. In case one wants an item to match zero or more times,
# the function can be proceeded by a '*' string.
# Example:
# ```coffeescript
# matchAny = (node) -> true
# matchDiv = (node) -> node.tag is 'div'
# matchPhoto = (node) -> node.className.match /\bphoto\b/
# Xml.search nodeTree, '*', matchAny, matchDiv, matchPhoto
# ```
#
# Usually though, other matching abstractions will be used, which are converted
# to matching functions automatically. When an object is passed, all its
# properties must match the node's. Search properties can be
#   - strings: must be equal to the XML property,
#   - `RegExp`s: must match the XML property, or
#   - `true`: the XML property only needs to exist.
# ```coffeescript
# Xml.search nodeTree, '*', {}, {tag: 'div'}, {className: /\bphoto\b/}
# ```
# 
# Also, `and`, `or` and `not` modifiers can be used:
# ```coffeescript
# Xml.search nodeTree, '*', {}, ['or', {tag: 'section'}, {className: 'mysection'}], {innerText: 'test'}
# ```
# The `'*', {}` combination matches any point in the tree, where a node must be found that has either
# a tag name 'section' or class name 'mysection', and that has a node or nodes that have the string
# 'test' as their only child content.
#
# For simple cases, a string based format can be used. The above examples can be rewritten:
# ```coffeescript
# Xml.search nodeTree, '*. div .photo' # a single string arg will be split on spaces
# Xml.search nodeTree, '*.', 'section,.mysection', {innerText: 'test'}
# ```

exports.search = (node,_terms...) ->
	switch _terms.length
		when 0
			return []
		when 1
			term = _terms[0]
			if typeof term is 'string'
				_terms = term.split ' '
			else if term instanceof Array
				_terms = term
	
	terms = []
	for term in _terms
		if typeof term is 'string' and term[0]=='*'
			terms.push '*'
			term = term.substr 1
			continue if !term.length
		terms.push termToFunc(term)

	results = []

	searchRecurse = (node,termPos) ->
		func = terms[termPos++]

		if func=='*' # term that follows may be repeated zero or more times
			func = terms[termPos]

			# 1. don't match `node` and skip to next term
			if termPos+1 < terms.length
				searchRecurse node, termPos+1
			# 2. match `node` and let the repeated term apply to children as well
			termPos--

		if func(node)
			if termPos < terms.length
				if node.children
					for child in node.children when typeof child is 'object'
						searchRecurse child, termPos
			else
				results.push node
		return
				
	searchRecurse node, 0

	results


termToFunc = (term) ->
	
	if typeof term=='function'
		return term

	if typeof term is 'string'
		if term[0]=='^'
			term = ('not,'+term).split ','
		else if term.indexOf(',')>=0
			term = ('or,'+term).split ','
		else if term[0]=='#'
			term = term.substr 1
			return (node) -> node.id==term
		else
			[tag,className] = term.split '.'
			term = {}
			term.tag = tag if tag
			term.className = new RegExp("\\b"+className.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')+"\\b") if className
	
	if term instanceof Array
		func = term.shift()
		for t,n in term
			term[n] = termToFunc t
		return if func=='or' then (node) ->
			return true for t in term when t(node)
			false
		else if func=='and' then (node) ->
			return false for t in term when !t(node)
			true
		else if func=='not' then (node) ->
			return false for t in term when t(node)
			true
		else
			throw new Error('invalid op: '+func)
	
	if typeof term=='object'
		for k of term
			# not empty
			return (node) ->
				for key,val of term
					if !node[key] or !(val==true or (if typeof val is "string" then node[key]==val else node[key].match(val)))
						return false
				return true

	return -> true



selfClosing =
	area: true
	base: true
	br: true
	col: true
	command: true
	embed: true
	hr: true
	img: true
	input: true
	keygen: true
	link: true
	meta: true
	param: true
	source: true
	track: true
	wbr: true

entities =
	aacute: "á"
	Aacute: "Á"
	acirc: "â"
	Acirc: "Â"
	acute: "´"
	aelig: "æ"
	AElig: "Æ"
	agrave: "à"
	Agrave: "À"
	alefsym: "ℵ"
	alpha: "α"
	Alpha: "Α"
	amp: "&"
	and: "⊥"
	ang: "∠"
	aring: "å"
	Aring: "Å"
	asymp: "≈"
	atilde: "ã"
	Atilde: "Ã"
	auml: "ä"
	Auml: "Ä"
	bdquo: "„"
	beta: "β"
	Beta: "Β"
	brvbar: "¦"
	bull: "•"
	cap: "∩"
	ccedil: "ç"
	Ccedil: "Ç"
	cedil: "¸"
	cent: "¢"
	chi: "χ"
	Chi: "Χ"
	circ: "ˆ"
	clubs: "♣"
	cong: "≅"
	copy: "©"
	crarr: "↵"
	cup: "∪"
	curren: "¤"
	dagger: "†"
	Dagger: "‡"
	darr: "↓"
	dArr: "⇓"
	deg: "°"
	delta: "δ"
	Delta: "Δ"
	diams: "♦"
	divide: "÷"
	eacute: "é"
	Eacute: "É"
	ecirc: "ê"
	Ecirc: "Ê"
	egrave: "è"
	Egrave: "È"
	empty: "∅"
	emsp: " "
	ensp: " "
	epsilon: "ε"
	Epsilon: "Ε"
	equiv: "≡"
	eta: "η"
	Eta: "Η"
	eth: "ð"
	ETH: "Ð"
	euml: "ë"
	Euml: "Ë"
	exist: "∃"
	fnof: "ƒ"
	forall: "∀"
	frac12: "½"
	frac14: "¼"
	frac34: "¾"
	frasl: "⁄"
	gamma: "γ"
	Gamma: "Γ"
	ge: "≥"
	gt: ">"
	harr: "↔"
	hArr: "⇔"
	hearts: "♥"
	hellip: "…"
	iacute: "í"
	Iacute: "Í"
	icirc: "î"
	Icirc: "Î"
	iexcl: "¡"
	igrave: "ì"
	Igrave: "Ì"
	image: "ℑ"
	infin: "∞"
	int: "∫"
	iota: "ι"
	Iota: "Ι"
	iquest: "¿"
	isin: "∈"
	iuml: "ï"
	Iuml: "Ï"
	kappa: "κ"
	Kappa: "Κ"
	lambda: "λ"
	Lambda: "Λ"
	lang: "〈"
	laquo: "«"
	larr: "←"
	lArr: "⇐"
	lceil: "⌈"
	ldquo: "“"
	le: "≤"
	lfloor: "⌊"
	lowast: "∗"
	loz: "◊"
	lsaquo: "‹"
	lsquo: "‘"
	lt: "<"
	macr: "¯"
	mdash: "—"
	micro: "µ"
	middot: "·"
	minus: "−"
	mu: "μ"
	Mu: "Μ"
	nabla: "∇"
	nbsp: "&#160;"
	ndash: "–"
	ne: "≠"
	ni: "∋"
	not: "¬"
	notin: "∉"
	nsub: "⊄"
	ntilde: "ñ"
	Ntilde: "Ñ"
	nu: "ν"
	Nu: "Ν"
	oacute: "ó"
	Oacute: "Ó"
	ocirc: "ô"
	Ocirc: "Ô"
	oelig: "œ"
	OElig: "Œ"
	ograve: "ò"
	Ograve: "Ò"
	oline: "‾"
	omega: "ω"
	Omega: "Ω"
	omicron: "ο"
	Omicron: "Ο"
	oplus: "⊕"
	or: "⊦"
	ordf: "ª"
	ordm: "º"
	oslash: "ø"
	Oslash: "Ø"
	otilde: "õ"
	Otilde: "Õ"
	otimes: "⊗"
	ouml: "ö"
	Ouml: "Ö"
	para: "¶"
	part: "∂"
	permil: "‰"
	perp: "⊥"
	phi: "φ"
	Phi: "Φ"
	piv: "ϖ"
	pi: "π"
	Pi: "Π"
	plusmn: "±"
	pound: "£"
	prime: "′"
	Prime: "″"
	prod: "∏"
	prop: "∝"
	psi: "ψ"
	Psi: "Ψ"
	quot: '"'
	radic: "√"
	rang: "〉"
	raquo: "»"
	rarr: "→"
	rArr: "⇒"
	rceil: "⌉"
	rdquo: "”"
	real: "ℜ"
	reg: "®"
	rfloor: "⌋"
	rho: "ρ"
	Rho: "Ρ"
	rsaquo: "›"
	rsquo: "’"
	sbquo: "‚"
	scaron: "š"
	Scaron: "Š"
	sdot: "⋅"
	sect: "§"
	sigmaf: "ς"
	sigma: "σ"
	Sigma: "Σ"
	sim: "∼"
	spades: "♠"
	sub: "⊂"
	sube: "⊆"
	sum: "∑"
	sup: "⊃"
	sup1: "¹"
	sup2: "²"
	sup3: "³"
	supe: "⊇"
	szlig: "ß"
	tau: "τ"
	Tau: "Τ"
	there4: "∴"
	thetasym: "ϑ"
	theta: "θ"
	Theta: "Θ"
	thinsp: " "
	thorn: "þ"
	THORN: "Þ"
	tilde: "˜"
	times: "×"
	trade: "™"
	uacute: "ú"
	Uacute: "Ú"
	uarr: "↑"
	uArr: "⇑"
	ucirc: "û"
	Ucirc: "Û"
	ugrave: "ù"
	Ugrave: "Ù"
	uml: "¨"
	upsih: "ϒ"
	upsilon: "υ"
	Upsilon: "Υ"
	uuml: "ü"
	Uuml: "Ü"
	weierp: "℘"
	xi: "ξ"
	Xi: "Ξ"
	yacute: "ý"
	Yacute: "Ý"
	yen: "¥"
	yuml: "ÿ"
	Yuml: "Ÿ"
	zeta: "ζ"
	Zeta: "Ζ"

