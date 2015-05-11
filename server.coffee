Db = require 'db'
Event = require 'event'
Http = require 'http'
Photo = require 'photo'
Plugin = require 'plugin'
Subscription = require 'subscription'

exports.getTitle = -> # we implemented our own title input

exports.client_searchSub = (cb) !->
	cb.subscribe 'search:'+Plugin.userId()

exports.client_search = (text) !->
	Http.get
		query: text
		searchYahoo: true
		name: 'httpSearch'
		args: [Plugin.userId()]

exports.client_add = (text) !->
	if typeof text is 'object'
		if text.photoguid
			text.by = Plugin.userId()
			Photo.claim text.photoguid, text
		else
			addTopic Plugin.userId(), text # not used for search results anymore
	else if (text.toLowerCase().indexOf('http') is 0 or text.toLowerCase().indexOf('www.') is 0) and text.split(' ').length is 1
		Http.get
			url: text
			getMetaTags: true
			name: 'httpTags'
			memberId: Plugin.userId()
			args: [Plugin.userId()]
	else
		addTopic Plugin.userId(), title: text

exports.onPhoto = (info, data) !->
	#log 'info > ' + JSON.stringify(info)
	#log 'data > ' + JSON.stringify(data)
	if info.key and data.by
		data.photo = info.key
		addTopic data.by, data

exports.httpSearch = (userId, data) !->
	Subscription.push 'search:'+userId, data

exports.httpTags = (userId, data) !->
	#log 'httpTags received: '+JSON.stringify(data)
	if !data.url
		# url was probably malformed, just add as title
		addTopic userId, title: data.title
	else
		addTopic userId, data

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

	name = Plugin.userName(userId)
	Event.create
		text: "#{name} added topic: #{topic.title}"
		sender: userId

exports.client_remove = (id) !->
	return if Plugin.userId() isnt Db.shared.get(id, 'by') and !Plugin.userIsAdmin()
	Db.shared.remove(id)
