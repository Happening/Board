Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Social = require 'social'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

exports.render = !->
	topicId = Page.state.get(0)
	if topicId
		renderTopic(topicId)
	else
		renderForum()


renderTopic = (topicId) !->
	Page.setTitle tr("Topic")
	topic = Db.shared.ref(topicId)
	Event.showStar topic.get('title')
	if Plugin.userId() is topic.get('by') or Plugin.userIsAdmin()
		Page.setActions
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Remove topic?"), !->
					Server.sync 'remove', topicId, !->
						Db.shared.remove(topicId)
					Page.back()
	Dom.div !->
		Dom.style margin: '-8px -8px 0', paddingBottom: '8px', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Dom.div !->
			Dom.style Box: 'top', Flex: 1, padding: '8px'

			imgUrl = false
			if image = topic.get('image')
				imgUrl = image
			else if key = topic.get('photo')
				imgUrl = Photo.url key, 400

			if imgUrl
				Dom.img !->
					Dom.style
						maxWidth: '120px'
						maxHeight: '200px'
						margin: '2px 8px 4px 2px'
					Dom.prop 'src', imgUrl

			Dom.div !->
				Dom.style Flex: 1, fontSize: '90%'
				Dom.h3 !->
					Dom.style marginTop: 0
					Dom.text topic.get('title')
				Dom.text topic.get('description')

				if url = topic.get('url')
					domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
					Dom.div !->
						Dom.style
							marginTop: '6px'
							color: '#aaa'
							fontSize: '90%'
							whiteSpace: 'nowrap'
							textTransform: 'uppercase'
							fontWeight: 'normal'
						Dom.text domain

			if url = topic.get('url')
				Dom.onTap !->
					Plugin.openUrl url

		expanded = Obs.create false
		byUserId = topic.get('by')
		Dom.div !->
			Dom.style
				margin: '4px 8px 0 8px'
				fontSize: '70%'
				color: '#aaa'
			Dom.text tr("Added by %1", Plugin.userName(byUserId))
			Dom.text " • "
			Time.deltaText topic.get('time')

			Dom.text " • "
			expanded = Social.renderLike
				path: [topicId]
				id: 'topic'
				userId: byUserId
				aboutWhat: tr("topic")

		Obs.observe !->
			if expanded.get()
				Dom.div !->
					Dom.style margin: '0 8px 0 8px'

					Social.renderLikeNames
						path: [topicId]
						id: 'topic'
						userId: byUserId

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments(topicId)

renderForum = !->
	addingTopic = Obs.create 0
	Ui.list !->
		searchResult = Obs.create false
		searchLast = Obs.create false
		searching = Obs.create false
		Server.send "searchSub", (result) !->
			searching.set false
			searchResult.set result

		addE = null
		addingUrl = Obs.create false
		editingInput = Obs.create false


		search = !->
			return if !(val = addE.value().trim())
			searching.set true
			searchResult.set false
			searchLast.set val
			Server.send 'search', val

		save = !->
			return if !(val = addE.value().trim())
			if addingUrl.get()
				addingTopic.set 0|Db.shared.get('maxId')+1
				Server.sync 'add', val
			else
				Page.nav !->
					Page.setTitle tr("New topic")
					Form.setPageSubmit (values) !->
						Server.call 'add', values
						Page.back()
					, true

					photoForm = Form.hidden 'photoguid'
					photoThumb = Obs.create false

					Dom.div !->
						Dom.style
							Box: true
							padding: '8px'
							margin: '-8px'
							backgroundColor: '#fff'
							borderBottom: '2px solid #ddd'
						Dom.div !->
							Dom.style
								width: '75px'
								height: '75px'
								margin: '20px 10px 0 0'
							photo = Photo.unclaimed 'topicPhoto'
							log 'photo', photo
							if photo
								photoForm.value photo.claim()
								photoThumb.set photo.thumb

							if pt = photoThumb.get()
								log 'got thumb', pt
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
									background:  "url(#{Plugin.resourceUri('addphoto.png')}) 50% 50% no-repeat"
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


		# Top entry: adding an topic
		Ui.item !->
			Dom.style padding: '8px 4px'
			addE = Form.text
				simple: true
				name: 'topic'
				text: tr("+ Enter title, keywords or url")
				onChange: (v) !->
					v = v?.trim()||''
					if v
						editingInput.set v
						isUrl = v.split(' ').length is 1 and (v.toLowerCase().indexOf('http') is 0 or v.toLowerCase().indexOf('www.') is 0)
						addingUrl.set !!isUrl
					else
						editingInput.set false
						searchResult.set false
						addingUrl.set false
				onReturn: save
				inScope: !->
					Dom.style
						Flex: 1
						display: 'block'
						fontSize: '100%'
						border: 'none'
					Dom.prop 'rows', 1

		Obs.observe !->
			if editingInput.get() and !searching.get()
				Ui.item !->
					Dom.style padding: '8px 4px', color: Plugin.colors().highlight
					Icon.render
						data: 'edit'
						size: 18
						color: Plugin.colors().highlight
						style:
							padding: '0 16px'
							marginRight: '10px'
					Dom.div (if addingUrl.get() then tr("Add URL") else tr("Create new topic"))
					Dom.onTap save

				if editingInput.get() isnt searchLast.get()
					Ui.item !->
						Dom.style padding: '8px 4px', color: Plugin.colors().highlight
						Icon.render
							data: 'world'
							size: 18
							color: Plugin.colors().highlight
							style:
								padding: '0 16px'
								marginRight: '10px'
						Dom.div tr("Show web suggestions")
						Dom.onTap search

		Obs.observe !->
			results = searchResult.get()
			log 'got some results', results
			if results
				for result in results then do (result) !->
					topic = Obs.create result
					Ui.item !->
						Dom.style padding: '8px 4px'
						renderListTopic topic, true, !->
							Dom.div !->
								Dom.style color: '#aaa', fontSize: '75%', marginTop: '6px'
								desc = result.description || ''
								Dom.text desc.slice(0, 120) + (if desc.length>120 then '...' else '')
						Dom.onTap !->
							Server.sync 'add', result
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
			maxId = Db.shared.get 'maxId'
			if addingTopic.get()>maxId
				Ui.item !->
					Dom.style padding: '8px 4px', color: '#aaa'
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
					padding: '8px 4px'
					Box: 'middle'

				renderListTopic topic, false, !->
					Dom.div !->
						Dom.style
							Box: true
							margin: '4px 0'
							fontSize: '70%'
							color: '#aaa'
						Dom.div !->
							Dom.text Plugin.userName(topic.get('by'))
							Dom.text " • "
							Time.deltaText topic.get('time'), 'short'

						Dom.div !->
							Dom.style Flex: 1, textAlign: 'right', fontWeight: 'bold', marginTop: '1px', paddingRight: '2px'

							if commentCnt = Db.shared.get('comments', topic.key(), 'max')
								Dom.span !->
									Dom.style display: 'inline-block', padding: '5px 0 5px 8px', margin: '-7px -3px'
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
									Dom.style display: 'inline-block', padding: '5px 0 5px 10px', margin: '-7px -3px'
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
				newTime = if Event.isNew(topic.get('time')) then -topic.get('time') else 0
				unreadCount = -Event.getUnread([topic.key()])
				[newTime, unreadCount, -topic.key()]

		Obs.observe !->
			log 'empty now', empty.get()
			if empty.get()
				Ui.item !->
					Dom.style
						padding: '12px 0'
						textAlign: 'center'
						color: '#bbb'
					Dom.text tr("No topics")


renderListTopic = (topic, searchResult, bottomContent) !->
	Dom.div !->
		Dom.style
			margin: '0 10px 0 0'
			width: '50px'
			height: '50px'

		bgUrl = false
		if image = topic.get('image')
			bgUrl = image
		else if key = topic.get('photo')
			bgUrl = Photo.url key, 400

		if bgUrl
			Dom.style
				backgroundImage: "url(#{bgUrl})"
				backgroundSize: 'cover'
				backgroundPosition: '50% 50%'
		else
			Dom.style
				backgroundColor: '#eee'

	Dom.div !->
		Dom.style Flex: 1, color: (if Event.isNew(topic.get('time')) then '#5b0' else 'inherit')
		Dom.div !->
			Dom.style Box: true
			if !searchResult
				Dom.style minHeight: '30px'

			Dom.div !->
				Dom.style Flex: 1
				Dom.span !->
					Dom.style paddingRight: '6px'
					Dom.userText topic.get('title')
				if (url = topic.get('url')) and searchResult
					domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
					Dom.span !->
						Dom.style
							color: '#aaa'
							textTransform: 'uppercase'
							fontSize: '70%'
							fontWeight: 'normal'
						Dom.text ' '+domain

			Dom.div !->
				Dom.style Box: 'middle', marginRight: '-6px'
				Event.renderBubble [topic.key()]


		bottomContent() if bottomContent
