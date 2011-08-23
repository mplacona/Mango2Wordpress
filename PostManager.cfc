<cfcomponent displayname="PostManager" output="false">
	<cffunction name="init" access="public" output="false" returntype="Object" hint="constructor">
		<cfargument name="mango_dsn" type="string" required="true">
		<cfargument name="wordpress_dsn" type="string" required="true">
		
		<!--- Set the DSN's to be used globally by this component --->
	  	<cfset this.mango = arguments.mango_dsn>
		<cfset this.wordpress = arguments.wordpress_dsn>
		
      	<cfreturn this />
   	</cffunction>
	
	<cffunction name="getposts" returntype="query" access="private" hint="Return mangoblog posts content">
		<cfargument name="start" type="numeric" default="0" required="true">
		<cfargument name="limit" type="numeric" default="30" required="false">
		<cfquery datasource="#this.mango#" name="qPosts">
			SELECT E.id AS post_id, E.name, E.title, E.content, E.excerpt, E.last_modified, P.posted_on, E.status
			FROM  `entry` E
			INNER JOIN `post` P ON E.id = P.id
			LIMIT #arguments.start# , #arguments.limit#
		</cfquery>
		
		<cfreturn qPosts>
	</cffunction>
	
	<cffunction name="getPostComments" returntype="query" access="private" hint="get mangoblog post comments">
		<cfargument name="post_id" type="uuid" required="true">
		
		<cfquery datasource="#this.mango#" name="qComments">
			SELECT  `creator_email` ,  `creator_name` ,  `creator_url` ,  `created_on` ,  `content` 
			FROM  `comment` 
			WHERE entry_id =  '#arguments.post_id#'
		</cfquery>
		
		<cfreturn qComments>
	</cffunction>
	
	<cffunction name="getPostCategories" returntype="query" access="private" hint="get all the categories by mangoblog post">
		<cfargument name="post_id" type="uuid" required="true">
		
		<cfquery datasource="#this.mango#" name="qCategories">
			SELECT name, title, description
			FROM category C
			INNER JOIN post_category PC ON PC.category_id = C.id
			WHERE PC.post_id =  '#arguments.post_id#'
			LIMIT 0 , 30
		</cfquery>
		
		<cfreturn qCategories>
	</cffunction>
	
	<cffunction name="getMaxPost" returntype="numeric" access="private" hint="lazy function to get the added post id">
		<cfquery datasource="#this.wordpress#" name="qMax">
			SELECT max(id) as MaxPost FROM `wp_posts` 
		</cfquery>
		
		<cfreturn qMax.MaxPost>
	</cffunction>
	
	<!--- Function found on http://snippets.dzone.com/posts/show/10439 published by parkerst (http://snippets.dzone.com/user/parkerst) --->
	<cffunction name="javaReg" returnType="Array" access="private">
		<cfargument name="regExp" required="true">
		<cfargument name="string" required="true">
		<cfargument name="flags" required="false" default="" type="string">
	
		<cfscript>
			var regPattern =  CreateObject("java","java.util.regex.Pattern");
			var regFlags = 0;
			var allFlags = StructNew();
			var thisFlag = '';
			var regMatches = ArrayNew(1);
			var i = 0;
			var regObj = false;
			var regMatcher = false;
			
			//make sure each flag is only used once
			allFlags.multiLine = 0;
			allFlags.dotAll = 0;
			allFlags.Case_Insensitive = 0;
	
			if( len(arguments.flags) ) {
				for(i=1; i LTE len(arguments.flags); i++ ) {
					thisFlag = mid(arguments.flags,i,1);
					if( thisFlag EQ "m" AND allFlags.multiLine EQ 0 ) {
						regFlags = regFlags + regPattern.MULTILINE;
						allFlags.multiline = 1;
					}
					if( thisFlag EQ "g" AND allFlags.dotAll EQ 0 ) {
						regFlags = regFlags + regPattern.DOTALL;
						allFlags.dotall = 1;
					}
					if( thisFlag EQ "i" AND allFlags.Case_Insensitive EQ 0 ) {
						regFlags = regFlags + regPattern.CASE_INSENSITIVE;
						allFlags.Case_Insensitive = 1;
					}
				}
			}
			
			regObj = regPattern.Compile(
				JavaCast( "string", arguments.regExp ),
				JavaCast( "int", regFlags )
				
			);
			regMatcher = regObj.Matcher(
				JavaCast( "string" , arguments.string )
			);
			
		</cfscript>
		<cfloop condition="regMatcher.Find()">
			<cfset arrayAppend( regMatches, regMatcher.Group() ) />
		</cfloop>
		<cfreturn regMatches />
	</cffunction>
	
	<cffunction name="cleanupPostCode" returntype="string" access="private" hint="You give me some post content and I'll clean it up and format it properly">
		<cfargument name="content" type="string" required="true">
		
		<cfset var content = arguments.content>
		<cfset var matches = javaReg('\<p\>\[code:[a-zA-Z]+\](.*?)\[\/code\]\<\/p\>',content,'g') />
		<cfset var strContent = "" />
					
		<cfloop array="#matches#" index="arrMatch">
			<cfset strContent = rereplace(arrMatch, 'code:([a-zA-Z]+)', 'code language="\1"', 'ALL') />
			<cfset content = replaceNoCase(content, arrMatch, strContent, "ALL") />
			
			<!--- Remove unnecessary line-breaks from code blocks --->
			<cfset content = rereplace(content, "<br \/?>", "\n", "ALL")>
			
			<!--- replace &lt; and &gt; with the tags themselves --->
			<cfset content = replace(content, "&lt;", "<", "ALL")>
			<cfset content = replace(content, "&gt;", ">", "ALL")>
		</cfloop>
		
		<!--- Remove the annoying p tags --->
		<cfset content = rereplace(content, "</?p>", "", "ALL") />
		
		<!--- Now remove the old "textareas" --->
		<cfset content = rereplace(content, '<textarea[^>]+class=\"([a-zA-Z]+)\"\>', '[code language="\1"]', "ALL") />
		<cfset content = replace(content, '</textarea>', '[/code]', "ALL") />
		
		<cfreturn content>
	</cffunction>
	
	<cffunction name="insertPostWordpress" returntype="void" access="private" hint="inser a post into wordpress blog">
		<cfargument name="last_modified" type="any">
		<cfargument name="posted_on" type="any">
		<cfargument name="content" type="any">
		<cfargument name="title" type="any">
		<cfargument name="excerpt" type="any">
		<cfargument name="name" type="any">
		<cfargument name="commentCount" type="any">
		<cfargument name="status" type="any" default="published">
		
		<cfset var cleanContent = cleanupPostCode(arguments.content) />
		<cfset var cleanExcerpt = cleanupPostCode(arguments.excerpt) />
		
		
		<cfquery name="qInsert" datasource="#this.wordpress#">
			INSERT INTO `wp_posts` 
				(
					`ID`, 
					`post_author`, 
					`post_date`, 
					`post_date_gmt`, 
					`post_content`, 
					`post_title`, 
					`post_excerpt`, 
					`post_status`, 
					`comment_status`, 
					`ping_status`, 
					`post_password`, 
					`post_name`, 
					`to_ping`, 
					`pinged`, 
					`post_modified`, 
					`post_modified_gmt`, 
					`post_content_filtered`, 
					`post_parent`, 
					`guid`, 
					`menu_order`, 
					`post_type`, 
					`post_mime_type`, 
					`comment_count`
				) 
			VALUES 
				(
					NULL, 
					'1', 
					#createODBCDate(arguments.posted_on)#, 
					#createODBCDate(arguments.posted_on)#, 
					<cfqueryparam value="#cleanContent#">,
					<cfqueryparam value="#arguments.title#">, 
					<cfqueryparam value="#cleanExcerpt#">, 
					'publish', 
					'open', 
					'open', 
					'', 
					'#arguments.name#', 
					'', 
					'', 
					#createODBCDate(arguments.last_modified)#, 
					#createODBCDate(arguments.last_modified)#, 
					'', 
					'0', 
					'', 
					'0', 
					<cfif arguments.status EQ "draft">
						'revision',
					<cfelse>
						'post',
					</cfif> 
					'', 
					'#arguments.commentCount#'
				);
		</cfquery>
	</cffunction>
	
	<cffunction name="insertCommentPerPostWordpress" returntype="void" access="private" hint="Insert the comments to the newly added post">
		<cfargument name="post_id" type="any">
		<cfargument name="creator_name" type="any">
		<cfargument name="creator_email" type="any">
		<cfargument name="creator_url" type="any">
		<cfargument name="created_on" type="any">
		<cfargument name="content" type="any">
		
		<cfquery datasource="#this.wordpress#" name="qInsertComment">
			INSERT INTO  `wp_comments` 
				(
					`comment_ID` ,
					`comment_post_ID` ,
					`comment_author` ,
					`comment_author_email` ,
					`comment_author_url` ,
					`comment_author_IP` ,
					`comment_date` ,
					`comment_date_gmt` ,
					`comment_content` ,
					`comment_karma` ,
					`comment_approved` ,
					`comment_agent` ,
					`comment_type` ,
					`comment_parent` ,
					`user_id`
					)
			VALUES 
				(
					NULL,  
					'#arguments.post_id#',  
					'#arguments.creator_name#',  
					'#arguments.creator_email#', 
					'#arguments.creator_url#',  
					'',  
					#createODBCDate(arguments.created_on)#,  
					#createODBCDate(arguments.created_on)#, 
					<cfqueryparam value="#arguments.content#">,  
					'0',  
					'1',  
					'',  
					'',  
					'0',  
					'0'
				);

		</cfquery>
	</cffunction>
	
	<cffunction name="insertCategoriesPerPostWordpress" returntype="void" access="private" hint="for a given post, insert its categories if they don't exist, and associate it">
		<cfargument name="qCategories" type="query" required="true">
		<cfargument name="post_id" type="numeric" required="true">
		
		<cfset var qCategories = arguments.qCategories />
		<cfset var term_id = 0 />
		
		<cfif qCategories.recordCount>
			<cfloop query="qCategories">
				
				<!--- Check if the category already exists --->
				<cfquery datasource="#this.wordpress#" name="qCategoryExist">
					SELECT term_id
					FROM  `wp_terms` 
					WHERE slug =  '#qCategories.name#'
				</cfquery>
				
				<!--- If it doesn't, then add it --->
				<cfif NOT qCategoryExist.recordCount>
					<cftransaction>
						<cfquery datasource="#this.wordpress#" name="qInsertCategory">
							INSERT INTO  `wp_terms` 
								(						
									`term_id` ,
									`name` ,
									`slug` ,
									`term_group`
								)
							VALUES 
								(
									NULL ,  
									'#qCategories.title#',  
									'#qCategories.name#',  
									'0'
								);
						</cfquery>
						<cfquery datasource="#this.wordpress#" name="getNewID">
							SELECT LAST_INSERT_ID() AS term_id;
						</cfquery>				
					</cftransaction>
					
					<cfset term_id = getNewID.term_id />
					
					<cftransaction>
						<!--- Insert the term taxonomy --->
						<cfquery datasource="#this.wordpress#" name="qInsertTaxonomyCategory">
							INSERT INTO  `wp_term_taxonomy` 
								(
									`term_taxonomy_id` ,
									`term_id` ,
									`taxonomy` ,
									`description` ,
									`parent` ,
									`count`
								)
									VALUES (
									NULL ,  
									'#term_id#',  
									'category',  
									'#qCategories.description#',  
									'0',  
									'0'
								);
						</cfquery>
					</cftransaction>
				<cfelse>
					<cfset term_id = qCategoryExist.term_id />		
				</cfif>
				
				<!--- Get the taxonomy ID --->
				<cfquery datasource="#this.wordpress#" name="getTaxonomyId">
					SELECT 	term_taxonomy_id 
					FROM  	`wp_term_taxonomy`
					WHERE	term_id = '#term_id#'
				</cfquery>
				
				<!--- Now insert a relationship between the entry and the category (either existing or newly created) --->
				<cfquery datasource="#this.wordpress#" name="qRelateEntryCategory">
					INSERT INTO  `wp_term_relationships` 
						(
							`object_id` ,
							`term_taxonomy_id` ,
							`term_order`
						)
					VALUES 
						(
							'#arguments.post_id#',  
							'#getTaxonomyId.term_taxonomy_id#',  
							'0'
						);
				</cfquery>
			</cfloop>
		</cfif>
	</cffunction>

	<cffunction name="updateCategoryCounters" returntype="void" access="private" hint="categories have counters with number of posts, so they need to be updated during migration">
		<cfquery datasource="#this.wordpress#" name="qCategories">
			SELECT 	term_taxonomy_id
			FROM  	`wp_term_taxonomy` 
		</cfquery>
		
		<cfloop query="qCategories">
			<cfquery datasource="#this.wordpress#" name="qCategoryCounter">
				SELECT COUNT( object_id ) AS catCounter
				FROM wp_term_relationships
				WHERE term_taxonomy_id = #qCategories.term_taxonomy_id#
			</cfquery>
			
			<cfquery datasource="#this.wordpress#" name="qCounterupdate">
				UPDATE  `wp_term_taxonomy` SET count = #qCategoryCounter.catCounter# WHERE term_taxonomy_id = #qCategories.term_taxonomy_id#
			</cfquery>
		</cfloop>
		
	</cffunction>
	
	<cffunction name="batchPostWordpress" returntype="boolean" access="public" hint="the big boss. I'll delegate everything, and the functions will obey">
		<cfargument name="start" type="numeric" default="0" required="true">
		<cfargument name="limit" type="numeric" default="30" required="true">
		
		<cfset var qPosts = getposts(arguments.start, arguments.limit) />
		<cfset var newPost = 0 />
		

		<cfloop query="qPosts">
			<!--- Get the comments per post --->
			<cfset qComments = getPostComments(qPosts.post_id)>
			<cfset qCategories = getPostCategories(qPosts.post_id)>
			
			
			<!--- Insert the post --->
			<cfset insertPost = insertPostWordpress(
				last_modified : qPosts.last_modified,
				posted_on : qPosts.posted_on,
				content : qPosts.content,
				title : qPosts.title,
				excerpt : qPosts.excerpt,
				name : qPosts.name,
				commentCount : qComments.recordCount,
				status : qPosts.status
			) />
			
			<cfset newPost = getMaxPost()>
			
			<!--- insert post's comments --->
			<cfloop query="qComments">
				<cfset insertComment = insertCommentPerPostWordpress(
					post_id : newPost,
					creator_name : qComments.creator_name,
					creator_email : qComments.creator_email,
					creator_url : qComments.creator_url,
					created_on : qComments.created_on,
					content : qComments.content
				) />
			</cfloop>
			
			<!--- insert posts's categories --->
			<cfset insertCategories = insertCategoriesPerPostWordpress(
				qCategories : qCategories,
				post_id : newPost
			) />
			
			<!--- Update the counters for categories --->
			<cfset updateCounters = updateCategoryCounters() />
			
		</cfloop>
		
		<cfreturn 1>
	</cffunction>
</cfcomponent>