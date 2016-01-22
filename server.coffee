Db = require 'db'
Event = require 'event'
Http = require 'http'
Metatags = require 'metatags'
OAuth = require 'oauth'
Photo = require 'photo'
App = require 'app'

# The `secrets.server.coffee` file cannot be added to the git repo, for
# obvious reasons. The function should return Yahoo credentials like:
# `["verylongid09ves4u5w9serawevwa9r9ws8erus8fv9ws8ers--", "passworddfsnsd3ufgnsidu5fndsufg"]`
yahooConsumerPair = require('secrets').yahooConsumerPair()

exports.client_search = (text,cb) !->
	request =
		url: 'https://yboss.yahooapis.com/ysearch/limitedweb?format=json&q=' + encodeURIComponent(text)
		cb: ['onSearchResults', cb]
	OAuth.sign request, yahooConsumerPair
	Http.get request

exports.onSearchResults = (cb, resp) !->
	metas = {_MODE_:'replace'}
	if resp.body and (data = JSON.parse(resp.body)) and (results = data?.bossresponse?.limitedweb?.results)
		i = cnt = 0
		while cnt<3 and i<results.length
			url = results[i++].url
			if prevUrl and url.substr(0,prevUrl.length)==prevUrl
				continue
			metas[cnt++] = {url}
			prevUrl = url

	# Immediately show url search results
	cb.reply metas

	# Asynchronously fetch meta info for these pages
	for pos in [0...cnt] by 1
		url = metas[pos].url
		Http.get
			url: url
			cb: ['onSearchMeta', cb, url, pos]

exports.onSearchMeta = (cb, url, pos, resp) !->
	if resp.body and meta = Metatags.fromHtml(resp.body)
		meta.url = url
	else
		meta = {url}
	#log 'onSearchMeta', url, pos, JSON.stringify meta
	push = {}
	push[pos] = meta
	cb.reply push


exports.client_add = (text) !->
	if typeof text is 'object'
		if text.photoguid
			text.by = App.userId()
			Photo.claim text.photoguid, text
		else
			addTopic App.userId(), text # not used for search results anymore
	else if (text.toLowerCase().indexOf('http') is 0 or text.toLowerCase().indexOf('www.') is 0) and text.split(' ').length is 1
		Http.get
			url: text
			cb: ['httpTags', App.userId(), text]
			memberId: App.userId()
	else
		addTopic App.userId(), title: text

exports.onPhoto = (info, data) !->
	#log 'info > ' + JSON.stringify(info)
	#log 'data > ' + JSON.stringify(data)
	if info.key and data.by
		data.photo = info.key
		addTopic data.by, data

exports.httpTags = (userId, url, resp) !->
	if resp.body and meta = Metatags.fromHtml(resp.body)
		meta.url = url
		addTopic userId, meta
	else
		# url was probably malformed, just add as title
		addTopic userId, title:url

addTopic = (userId, data) !->
	topic =
		title: data.title
		description: data.description||''
		url: data.url
		time: 0|(new Date()/1000)
		by: userId

	if data.image
		topic.image = data.image
	if data.imageThumb
		topic.imageThumb = data.imageThumb
	if data.photo
		topic.photo = data.photo

	maxId = Db.shared.incr('maxId')
	Db.shared.set(maxId, topic)

	name = App.userName(userId)
	Event.create
		text: "#{name} added topic: #{topic.title}"
		sender: userId

exports.client_remove = (id) !->
	return if App.userId() isnt Db.shared.get(id, 'by') and !App.userIsAdmin()
	Db.shared.remove(id)
