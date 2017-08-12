request = require 'request'
sax = require 'sax'
async = require 'async'
zlib = require 'zlib'
urlParser = require 'url'

headers =
	'user-agent': '404check.io (http://404check.io)'
agentOptions =
	keepAlive: true
request = request.defaults {headers, agentOptions, timeout: 60000}

class SitemapParser
	constructor: (@url_cb, @sitemap_cb) ->
		@visited_sitemaps = {}

	_download: (url, parserStream) ->

		if url.lastIndexOf('gz') is url.length - 2
			unzip = zlib.createUnzip()
			request.get({url, encoding: null}).pipe(unzip).pipe(parserStream)
		else
			return request.get({url, gzip:true}).pipe(parserStream)

	parse: (url, done) =>
		isURLSet = false
		isSitemapIndex = false
		inLoc = false

		@visited_sitemaps[url] = true

		parserStream = sax.createStream false, {trim: true, normalize: true, lowercase: true}
		parserStream.on 'opentag', (node) =>
			inLoc = node.name is 'loc'
			isURLSet = true if node.name is 'urlset'
			isSitemapIndex = true if node.name is 'sitemapindex'
		parserStream.on 'error', (err) =>
			done err
		parserStream.on 'text', (text) =>
			if inLoc
				if isURLSet
					@url_cb text
				else if isSitemapIndex
					if @visited_sitemaps[text]?
						console.error "Already parsed sitemap: #{text}"
					else
						@sitemap_cb text
		parserStream.on 'end', () =>
			done null

		@_download url, parserStream

exports.parseSitemap = (url, url_cb, sitemap_cb, done) ->
	sitemapParser = new SitemapParser url_cb, sitemap_cb
	sitemapParser.parse url, done

exports.parseSitemaps = (urls, url_cb, done) ->
	urls = [urls] unless urls instanceof Array
	visited_sitemaps = []

	queue = async.queue (url, done) ->
		sitemapParser = new SitemapParser url_cb, (sitemap) ->
			queue.push urlParser.resolve url, sitemap

		sitemapParser.parse url, () ->
			Array::push.apply visited_sitemaps, Object.keys(sitemapParser.visited_sitemaps)
			done()
	, 4
	queue.drain = () ->
		done null, visited_sitemaps
	queue.push urls

exports.sitemapsInRobots = (url, cb) ->
	request.get url, (err, res, body) ->
		return cb err if err
		return cb "statusCode: #{res.statusCode}" if res.statusCode isnt 200
		matches = []
		body.replace /^Sitemap:\s?([^\s]+)$/igm, (m, p1) ->
			matches.push(p1)
		cb null, matches
