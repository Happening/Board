App = require 'app'
Transform = require 'transform'

encode = encodeURIComponent
decode = decodeURIComponent

exports.sign = (request, consumerPair, accessPair) !->

	[baseUri,getData] = request.url.split '?'
	httpMethod = request.method ? (if request.data then 'POST' else 'GET')
	
	time = 0|App.time()
	oauth =
		oauth_consumer_key: consumerPair[0]
		oauth_nonce: time
		oauth_signature_method: 'HMAC-SHA1'
		oauth_timestamp: time
		oauth_version: '1.0'

	oauth.oauth_token = accessPair[2] if accessPair
	
	params = []
	for data in [getData,request.data] when data
		for param in data.split('&')
			[k,v] = param.split('=')
			params[decode k] = decode v
	for k,v of oauth
		params[k] = v

	keys = []
	keys.push k for k of params
	keys.sort()

	for k,i in keys
		keys[i] = encode(k) + '=' + encode(params[k])

	baseString = httpMethod + "&" + encode(baseUri) + '&' + encode(keys.join '&')

	compositeKey = encode(consumerPair[1]) + '&'
	compositeKey += encode(accessPair[1]) if accessPair
	oauth.oauth_signature = Transform.hmac('sha1', baseString, compositeKey, true)

	res = []
	for k,v of oauth
		res.push "#{encode(k)}=\"#{encode(v)}\""

	request.headers ||= {}
	request.headers.Authorization = 'OAuth ' + res.join(', ')
	
	#log "baseString: #{baseString}"
	#log "compositeKey: #{compositeKey}"
	#log "header: #{request.headers.Authorization}"

