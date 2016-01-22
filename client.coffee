Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
App = require 'app'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

exports.render = !->
	topicId = Page.state.get(0)
	if topicId
		renderTopic(topicId)
	else
		renderBoard()


renderTopic = (topicId) !->
	Comments.enable legacyStore: topicId
	Page.setTitle tr("Topic")
	topic = Db.shared.ref(topicId)
	Event.showStar topic.get('title')
	if App.userId() is topic.get('by') or App.userIsAdmin()
		Page.setActions
			icon: 'delete'
			action: !->
				Modal.confirm null, tr("Remove topic?"), !->
					Server.sync 'remove', topicId, !->
						Db.shared.remove(topicId)
					Page.back()

	# Dom.div !->
	Dom.style ChildMargin: 0
	Dom.div !->
		Dom.style ChildMargin: 12

		Dom.div !->
			Dom.style Box: 'top'

			imgUrl = false
			if (key = topic.get 'imageThumb') or (key = topic.get 'photo')
				imgUrl = Photo.url key, 400
			else if image = topic.get('image')
				imgUrl = image

			if imgUrl
				Dom.img !->
					Dom.style
						maxWidth: '120px'
						maxHeight: '200px'
						marginBottom: '8px'
						marginRight: '8px'
					Dom.prop 'src', imgUrl

			url = topic.get('url')
			Dom.div !->
				Dom.style Flex: 1, fontSize: '90%'
				Dom.h3 !->
					Dom.style marginTop: 0
					if url
						Dom.text topic.get('title')
					else
						Dom.userText topic.get('title')

				if url
					Dom.text topic.get('description')
				else
					Dom.userText topic.get('description')

				if url
					domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
					Dom.div !->
						Dom.style
							color: '#aaa'
							fontSize: '90%'
							whiteSpace: 'nowrap'
							textTransform: 'uppercase'
							fontWeight: 'normal'
						Dom.text domain

			photoKey = topic.get('photo')
			if url or photoKey # tap either opens the url, or shows the photo
				Dom.onTap !->
					if url
						App.openUrl url
					else if photoKey
						Page.nav !->
							Page.setTitle tr("Topic photo")
							Dom.style
								padding: 0
								backgroundColor: '#444'
							require('photoview').render
								key: photoKey


		expanded = Obs.create false
		byUserId = topic.get('by')
		Dom.div !->
			Dom.style
				fontSize: '70%'
				color: '#aaa'
				marginTop: '12px'
			Dom.text tr("Added by %1", App.userName(byUserId))
			Dom.text " • "
			Time.deltaText topic.get('time')

			Dom.text " • "
			expanded = Comments.renderLike
				store: ['likes', topicId+'-topic']
				userId: byUserId
				aboutWhat: tr("topic")

		Obs.observe !->
			if expanded.get()
				Dom.div !->
					Dom.style margin: '0 8px 0 8px'
					Comments.renderLikeNames
						store: ['likes', topicId+'-topic']
						userId: byUserId

renderBoard = !->
	Page.setCardBackground()
	addingTopic = Obs.create 0
	Ui.list !->
		searchResult = Obs.create false
		searchLast = Obs.create false
		searching = Obs.create false

		addE = null
		addingUrl = Obs.create false
		editingInput = Obs.create false

		search = !->
			return if !(val = addE.value().trim())
			searching.set true
			searchResult.set false
			searchLast.set val
			Server.send 'search', val, (result) !->
				searchResult.merge result
				searching.set false

		save = !->
			return if !(val = addE.value().trim())

			newId = (0|Db.shared.get('maxId'))+1

			if addingUrl.get()
				addingTopic.set newId
				Event.subscribe [newId] # TODO: subscribe serverside
				Server.sync 'add', val
			else
				Page.nav !->
					Page.setTitle tr("New topic")
					Form.setPageSubmit (values) !->
						values.title = Form.smileyToEmoji values.title.trim()
						values.description = Form.smileyToEmoji values.description.trim()
						if !values.title or !values.description
							Modal.show tr("Please enter both a title and a description")
							return
						Event.subscribe [newId] # TODO: subscribe serverside
						Server.call 'add', values
						Page.back()
					, true

					photoForm = Form.hidden 'photoguid'
					photoThumb = Obs.create false

					Dom.div !->
						Dom.style
							Box: true
							backgroundColor: '#fff'
						Dom.div !->
							Dom.style
								width: '75px'
								height: '75px'
								margin: '20px 10px 0 0'
							photo = Photo.unclaimed 'topicPhoto'
							if photo
								photoForm.value photo.claim()
								photoThumb.set photo.thumb

							if pt = photoThumb.get()
								Dom.style border: 'none', background: 'none'
								Dom.img !->
									Dom.style
										display: 'block'
										width: '75px'
										maxHeight: '125px'
									Dom.prop 'src', pt
							else
								Dom.style
									border: '2px dashed #bbb'
									boxSizing: 'border-box'
									background:  "url(#{App.resourceUri('addphoto.png')}) 50% 50% no-repeat"
									backgroundSize: '32px'

							Dom.onTap !->
								Photo.pick null, null, 'topicPhoto'

						Dom.div !->
							Dom.style Flex: 1
							Form.input
								name: 'title'
								value: val
								text: tr("Title")
							Form.text
								name: 'description'
								text: tr("Description")


			addE.value ""
			editingInput.set false
			Form.blur()


		# Top entry: adding a topic
		Ui.item !->
			addE = Form.text
				simple: true
				name: 'topic'
				text: tr("+ Enter title, url, or search the web")
				onChange: (v) !->
					v = v?.trim()||''
					if v
						editingInput.set v
						isUrl = v.split(' ').length is 1 and (v.toLowerCase().indexOf('http') is 0 or v.toLowerCase().indexOf('www.') is 0)
						addingUrl.set !!isUrl
					else
						editingInput.set false
						searchResult.set false
						searchLast.set false
						addingUrl.set false
				onReturn: save
				style:
					Flex: 1
					display: 'block'
					fontSize: '100%'
					padding: 0
					border: 'none'
				onContent: (content) !->
					urls = []
					text = content
						.replace /([^\w\/]|^)www\./ig, '$1http://www.'
						.replace /\bhttps?:\/\/([a-z0-9\.\-]+\.[a-z]+)([/:][^\s\)'",<]*)?/ig, (url) ->
							if url[-1..] in ['.','!','?']
								# dropping the ? is questionable
								url = url[0...-1]
							urls.push url
					addE.value (if urls.length is 1 then urls[0] else content)
						# if it's one url in text, we'll only share the url

		Obs.observe !->
			if editingInput.get() and !searching.get()
				Ui.item !->
					Dom.style padding: '8px', color: App.colors().highlight
					Icon.render
						data: 'edit'
						size: 18
						color: App.colors().highlight
						style:
							padding: '0 16px'
							marginRight: '10px'
					Dom.div (if addingUrl.get() then tr("Add URL") else tr("Create new topic"))
					Dom.onTap save

				if editingInput.get() isnt searchLast.get()
					Ui.item !->
						Dom.style padding: '8px', color: App.colors().highlight
						Icon.render
							data: 'world'
							size: 18
							color: App.colors().highlight
							style:
								padding: '0 16px'
								marginRight: '10px'
						Dom.div tr("Show web suggestions")
						Dom.onTap search

		Obs.observe !->
			results = searchResult.get()
			#log 'got some results', results
			if results
				for pos,result of results then do (result) !->
					topic = Obs.create result
					Ui.item !->
						Dom.style padding: '8px'
						renderListTopic topic, true, !->
							Dom.div !->
								Dom.style color: '#aaa', fontSize: '75%', marginTop: '6px'
								desc = result.description || ''
								Dom.text desc.slice(0, 120) + (if desc.length>120 then '...' else '')
						Dom.onTap !->
							newId = (0|Db.shared.get('maxId'))+1
							addingTopic.set newId
							Event.subscribe [newId] # TODO: subscribe serverside
							log 'passing back result url: '+result.url
							Server.sync 'add', result.url
								# we should have OG caching in the future, so for now we 
								# just requery the search result url for OG tags
							searching.set false
							searchResult.set false
							addE.value ""
							editingInput.set false
							Form.blur()
			else if searching.get()
				Dom.div !->
					Dom.style
						Box: 'center'
						margin: '40px'
					Ui.spinner 24


	Ui.list !->
		Obs.observe !->
			maxId = 0|Db.shared.get 'maxId'
			if addingTopic.get()>maxId
				Ui.item !->
					Dom.style padding: '8px', color: '#aaa'
					Dom.div !->
						Dom.style
							Box: 'center middle'
							width: '50px'
							height: '50px'
							marginRight: '10px'
						Ui.spinner 24
					Dom.text tr("Adding...")

		count = 0
		empty = Obs.create(true)

		# List of all topics
		Db.shared.iterate (topic) !->
			empty.set(!++count)
			Obs.onClean !->
				empty.set(!--count)

			Ui.item !->
				Dom.style
					padding: '8px'
					Box: 'middle'

				renderListTopic topic, false, !->
					Dom.div !->
						Dom.style
							Box: true
							margin: '4px 0'
							fontSize: '70%'
							color: '#aaa'
						Dom.div !->
							Dom.text App.userName(topic.get('by'))
							Dom.text " • "
							Time.deltaText topic.get('time'), 'short'

						Dom.div !->
							Dom.style Flex: 1, textAlign: 'right', fontWeight: 'bold', marginTop: '1px', paddingRight: '4px'

							if commentCnt = Db.shared.get('comments', topic.key(), 'max')
								Dom.span !->
									Dom.style display: 'inline-block', padding: '5px 0 5px 8px'
									Icon.render
										data: 'comments'
										size: 13
										color: '#aaa'
										style: {verticalAlign: 'bottom', margin: '1px 2px 0 1px'}
									Dom.span commentCnt

							likeCnt = 0
							likeCnt++ for k,v of Db.shared.get('likes', topic.key()+'-topic') when +k and v>0
							if likeCnt
								Dom.span !->
									Dom.style display: 'inline-block', padding: '5px 0 5px 10px'
									Icon.render
										data: 'thumbup'
										size: 13
										color: '#aaa'
										style: {verticalAlign: 'bottom', margin: '0 2px 1px 1px'}
									Dom.span likeCnt


				Dom.onTap !->
					Page.nav topic.key()


		, (topic) ->
			if +topic.key()
				-topic.get('time')

		Obs.observe !->
			if empty.get()
				Ui.item !->
					Dom.style
						padding: '12px 0'
						Box: 'middle center'
						color: '#bbb'
					Dom.text tr("Nothing has been added yet")


renderListTopic = (topic, searchResult, bottomContent) !->
	Dom.div !->
		Dom.style
			margin: '0 10px 0 0'
			width: '50px'
			height: '50px'

		bgUrl = false
		if (key = topic.get 'imageThumb') or (key = topic.get 'photo')
			bgUrl = Photo.url key, 200
		else if image = topic.get('image') # legacy topics without a thumb
			bgUrl = image

		if bgUrl
			Dom.style
				backgroundImage: "url(#{bgUrl})"
				backgroundSize: 'cover'
				backgroundPosition: '50% 50%'
		else
			Icon.render data: 'placeholder', color: '#ddd', size: 48

	Dom.div !->
		Dom.style Flex: 1, color: (if Event.isNew(topic.get('time')) then '#5b0' else 'inherit')
		Dom.div !->
			Dom.style Box: true
			if !searchResult
				Dom.style minHeight: '30px'

			Dom.div !->
				Dom.style Flex: 1
				url = topic.get('url')
				Dom.span !->
					Dom.style paddingRight: '6px'
					if url
						Dom.text topic.get('title')
					else
						Dom.userText topic.get('title')
				if url and searchResult
					domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
					Dom.span !->
						Dom.style
							color: '#aaa'
							textTransform: 'uppercase'
							fontSize: '70%'
							fontWeight: 'normal'
						Dom.text ' '+domain

			Dom.div !->
				Dom.style Box: 'middle'
				Event.renderBubble [topic.key()]


		bottomContent() if bottomContent


exports.renderSettings = !->
	Form.input
		name: '_title'
		text: tr("Board topic")
		value: App.title()

