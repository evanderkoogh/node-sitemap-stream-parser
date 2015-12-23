sitemaps = require './sitemaps.coffee'
request = require 'request'
async = require 'async'

#url = 'http://www.amazon.com/sitemap_e_automotive.xml.gz'
#url = 'http://www.amazon.com/sitemap-manual-index.xml'
url = 'http://elabor8.com.au/sitemap.xml'
#url = 'http://21stcenturymba.com/sitemap.xml'

done = (err) ->
	console.log 'Done!'

i = 0
increaseI = (url) ->
	i++

printI = () ->
	console.log i

setInterval printI, 10000

sitemaps.parseRobot 'http://amazon.com/robots.txt', increaseI, done
#sitemaps.parseRobot 'http://yahoo.com/robots.txt', console.log, done

#sitemaps.parseSitemap url, console.log, done

#request.get {url, gzip:true}, (err, res, body) ->
#	console.log body