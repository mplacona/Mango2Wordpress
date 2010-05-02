<!--- NB: Don't forget to change the variable below with your DSN settings --->
<cfset posts = createObject("component", "PostManager").init	(
																	mango_dsn 		: 'mango',
																	wordpress_dsn 	: 'wordpress'
																) />

<!--- 
	The default limit is 30 posts. you can change this to whatever number you feel like
	If you have too many posts, with too many categories and too many comments,
	I'd suggest running it in batches of 150 or 200 posts depending on your numbers.
	Common sense is the key here. This is not likely to crash your server if you do
	otherwise, but will considerably slow down your server, and time-out if it becomes
	irresponsive.
--->																		
<cfset qPosts = posts.batchPostWordpress(
											start 	: 0,
											limit 	: 100
										) />
										
Done!