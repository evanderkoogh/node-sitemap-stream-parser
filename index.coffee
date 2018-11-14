request = require 'request'
sax = require 'sax'
async = require 'async'
zlib = require 'zlib'
urlParser = require 'url'

headers =
	'user-agent': process.env.USER_AGENT || 'node-sitemap-stream-parser';
agentOptions =
	keepAlive: true
	gzip: true
request = request.defaults {headers, agentOptions, timeout: 60000}

class SitemapParser
	constructor: (@url_cb, @sitemap_cb) ->
		@visited_sitemaps = {}

	_download: (url, parserStream, done) ->

		if url.lastIndexOf('.gz') is url.length - 3
			unzip = zlib.createUnzip()
			request.get({url, encoding: null}).pipe(unzip).pipe(parserStream)
		else
			stream = request.get({url, gzip:true})
			stream.on 'error', (err) =>
				done err
			return stream.pipe(parserStream)

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
			text = urlParser.resolve url, text
			if inLoc
				if isURLSet
					@url_cb text, url
				else if isSitemapIndex
					if @visited_sitemaps[text]?
						console.error "Already parsed sitemap: #{text}"
					else
						@sitemap_cb text
		parserStream.on 'end', () =>
			done null

		@_download url, parserStream, done

exports.parseSitemap = (url, url_cb, sitemap_cb, done) ->
	parser = new SitemapParser url_cb, sitemap_cb
	parser.parse url, done	

exports.parseSitemaps = (urls, url_cb, sitemap_test, done) ->
	unless done
		done = sitemap_test
		sitemap_test = undefined

	urls = [urls] unless urls instanceof Array

	parser = new SitemapParser url_cb, (sitemap) ->
		should_push = if sitemap_test then sitemap_test(sitemap) else true
		queue.push sitemap if should_push

	queue = async.queue parser.parse, 4
	queue.drain = () ->
		done null, Object.keys(parser.visited_sitemaps)
	queue.push urls

exports.parseSitemapsPromise = (urls, url_cb, sitemap_test) ->
	new Promise (resolve) ->
		exports.parseSitemaps(urls, url_cb, sitemap_test, resolve)

exports.sitemapsInRobots = (url, cb) ->
	request.get url, (err, res, body) ->
		return cb err if err
		return cb "statusCode: #{res.statusCode}" if res.statusCode isnt 200
		matches = []
		body.replace /^Sitemap:\s?([^\s]+)$/igm, (m, p1) ->
			matches.push(p1)
		cb null, matches
