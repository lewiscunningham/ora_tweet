# ora_tweet
A PL/SQL procedure to post to Twitter using a REST API

**NOTE:** This proc was written to use basic authentication. Twitter turned off basic authention in favor of OAuth (which makes sense and is a good thing), so this proc no longer works. It could be worked over to use OAuth but I have not chosen to take that on. It still makes for a good example of calling a REST API from inside the database.

# ​**Twitter Meets Oracle - ORA_Tweet**

  
In my search for fun and exciting things to do with an Oracle database, call it stupid database tricks, I find myself, in the deepest, darkest hours of the night, happily hacking away at those things that might not matter to anyone but a geek or a hacker. Sometimes though, my little excursions into PL/SQL nerdvanna turn up tools that find usefulness for the masses. Such it is with ORA_Tweet, my latest creation.  
  
I decided to put together a twitter procedure that would let me make posts from the database. When I first started coding it, it was going to just be a one off, fun thing with no real use. By the time I was finished though, I realized I do have a use case for it. I sometimes run long running processes. Currently, I have the database email me a status when it’s finished. Now I will have it tweet to me. If there is an error, I would still have it email the details but the status message can be a short and sweet “it succeeded”" or “it failed” message.

## ​Twitter

To understand the usefulness of an interface to Twitter, http://twitter.com, you need to know just exactly what Twitter is. I'm not really sure. It's sort of like IM but without the expectation that any particular person will be there to answer. It's very public. If you start your day off with a "Hello, Mom", everyone who follows you will see it.  
  
Messages on twitter are called tweets and cannot be longer than 140 characters. If you can't say it in 140 characters, you probably want to use a different medium. Trying to follow a conversation where a single tweet is spread over multiple tweets can be difficult.  
  
Twitter is also called a microblogging service. Micro as in a blog that contains less than or equal to 140 characters. I don't know anyone who uses it that way.  
  
In general, the goal of Twitter for most people is to communicate and stay in touch with people you know, would like to know or have interests in common. You "follow" people much like "friending" on other social networks. The people you follow show up in your stream. People talk about whatever it is that's on their minds. Sometimes you'll see people replying to each other and at other times, they just want to share a thought. 

**According to Twitter:** Twitter is a service for friends, family, and co–workers to communicate and stay connected through the exchange of quick, frequent messages. People write short updates,often called "tweets" of 140 characters or fewer. These messages are posted to your profile or [your blog](http://twitter.zendesk.com/forums/10711/entries/15354), sent to your followers[,](http://twitter.zendesk.com/forums/10711/entries/14019)and are searchable on Twitter search.
  
If you aren't on Twitter, I suggest that you sign up. Follow me, ORACLE_ACE, http://twitter.com/oracle_ace and say hi. There are many GUI tools for accessing Twitter such a TwitterBerry for BlackBerrys, Twhirl and Tweetdeck for Windows and many more.

## ​Twitter API

To make calls to twitter from a database, we need a method for plugging into twitter. Fortunately for us, Twitter provides an Application Programming Interface (API). An API is a programmatic method for interfacing with a service or sub-system; in our case the twitter service.

While Twitter provides an API to perform almost any interaction that you might wish for, arguably the most important is the ability to post a tweet. We will start with that API but will architect an expandable platform that will us to add any other APIs with minimal changes to existing code.  
  
The Twitter API uses the REST design paradigm. REST identifies a set of resources that you can interact with. REST is a fairly simple architecture once you understand the basics. In the case of Twitter, we can change our file extension and that will change the results that we get back. Twitter can return XML or JSON. For this article, I will return XML.  
  
The Twitter API also supports Basic Authentication. Basic authentication allows a user to pass in a user name/password associated with a URL. If you've ever tried to navigate to a web site and it popped up a dialog and asked for a username and password, that site was probably protected by basic authentication. Twitter has just recently started offering OAuth authentication. We'll go with basic authentication for this article.  
  
Twitter documents the status update API as this:

### ​statuses/update

Updates the authenticating user's status. Requires the status parameter specified below. Request must be a POST. A status update with text identical to the authenticating user's current status will be ignored.

**URL:**  http://twitter.com/statuses/update._format_

**Formats:** XML, json. Returns the posted status in requested format when successful.

**Method(s):** POST

**Parameters:**

-   status. Required. The text of your status update. Be sure to URL encode as necessary. Should not be more than 140 characters.
    
-   in_reply_to_status_id. Optional. The ID of an existing status that the status to be posted is in reply to. This implicitly sets the in_reply_to_user_id attribute of the resulting status to the user ID of the message being replied to. Invalid/missing status IDs will be ignored.
    

**Returns:**  [status element](http://apiwiki.twitter.com/REST+API+Documentation#Statuselement)

  
Notice that the method for update MUST be a POST. The return format can be modified by the extension on the URL (XML or JSON).  
  
Once authenticated, a status update URL will look something like this:  
  
HTTP://twitter.com/statuses/update.xml?status=HunkyDory

### ​Status Return

Since we're using XML, our return result will be XML. The return value from a status update is not particularly important. As long as you don't get an error, then your update was probably successful. The most likely reason for an error will be an invalid user name or password.  
  
According to the twitter documentation, the result will look like this (but formatted for either XML or JSON):

A status element consists of information on a status, with a nested _<user>_ element to describe the author.

    status
	    created_at
	    id
	    text
	    source 
	    truncated 
	    in_reply_to_status_id 
	    in_reply_to_user_id 
	    favorited
	    user
		    id
		    name
		    screen_name
		    description
		    location
		    profile_image_url
		    url
		    protected
		    followers_count

  
  

## ​The Database

I think that's enough about the Twitter API for now. Let's talk about the goal of our little project. I want to be able to update my status by calling a PL/SQL stored procedure. I'm running 10g XE, 10gR2 and 11g databases but there is no reason this code can't work on any Oracle data from the last decade or so. The bulk of the code will be created by making calls to the built-in package UTL_HTTP.

### ​UTL_HTTP

UTL_HTTP is a PL/SQL implementation of an HTTP requestor (or client). With UTL_HTTP you can make calls to a web server and return the results to your database. What this means is that the Oracle database has had the ability to access web services for many years.  
  
UTL_HTTP was added to the database quite a few version back. It actually existed in a limited form in Oracle 8. I remember using it to gather pieces of web pages many years ago. It wasn't until 9i that it added the ability to authenticate. I believe it was also 9i when the ability to authenticate for a proxy was added. Oracle 9i has been around a long time. If you are using a version before that, you *should* really think about upgrading.  
  
The Oracle 8 UTL_HTTP package provided only two functions: REQUEST( url, proxy_url) and REQUEST_PIECES(url, max_pieces, proxy_url ). The url is the address of the site requested. The proxy was an option proxy url (could not authenticate, only worked with already authenticated proxies). Request could only return up to 2000 bytes from a web site. Request_Pieces could return up to max_pieces (max of 32k) of 2000 byte pieces.  
  
I show you the Oracle 8 version as a contrast to the version available to Oracle 10g XE. This version of the package has 50 subprograms. It includes authentication, cookie handling, proxy authentication, redirects, error handling and even persistent connections. For our needs, we will only use a very small subset of these procedures. It's worth reading about them though.  
  
The procedures that we will use in our twitter client are:  
  
**SET_PROXY** Procedure - Sets the proxy to be used for requests of HTTP or other protocols

**BEGIN_REQUEST** Function - Begins a new HTTP request. UTL_HTTP establishes the network connection to the target Web server or the proxy server and sends the HTTP request line

**SET_HEADER** Procedure - Sets the maximum number of times UTL_HTTP follows the HTTP redirect instruction in the HTTP responses to future requests in the GET_RESPONSE function

**SET_AUTHENTICATION** Procedure - Sets HTTP authentication information in the HTTP request header. The Web server needs this information to authorize the request.

**WRITE_TEXT** Procedure - Writes some text data in the HTTP request body

**GET_RESPONSE** Function - Reads the HTTP response. When the function returns, the status line and the HTTP response headers have been read and processed

**READ_LINE** Procedure - Reads the HTTP response body in text form until the end of line is reached and returns the output in the caller-supplied buffer

**END_REQUEST** Procedure - Ends the HTTP request

**GET_DETAILED_SQLERRM** Function - Retrieves the detailed SQLERRM of the last exception raised  
  
We will also make a call to **UTL_URL.escape**. The escape procedure allows us to format a string so that it can be used in a URL. URLs do nor like special characters or spaces. Escape replaces those characters with information that can be used instead.

## ​Putting it Together

Now we put code together. The goal here is to make it as simple to use as possible but also make it easy to enhance. I am packaging up the procedure as I think it makes a lot of sense to use a package even when you will only have a single procedure. When it comes time to extend the functionality, the package will just make life easier.  
  
In the spec, we need a twitter username and password, a string that will be our status update and optionally, a user name and password for a proxy.

### ​The Spec

CREATE OR REPLACE PACKAGE ora_tweet  
AS  
  

    /* ORA_TWEET  
    Author: Lewis Cunningham  
    Date: Marchish, 2009  
    Email: lewisc@rocketmail.com  
    Twitter: oracle_ace  
    Web: http://database-geek.com  
    License: Free Use  
    Version: 1.1  
    */  
    FUNCTION tweet(  
		    p_user IN VARCHAR2,  
		    p_pwd IN VARCHAR2,  
		    p_string IN VARCHAR2,  
		    p_proxy_url IN VARCHAR2 DEFAULT NULL,  
		    p_no_domains IN VARCHAR2 DEFAULT NULL )  
	    RETURN BOOLEAN;  
    END ora_tweet;  
    /  
  
Short and sweet. Notice that the proxy url and domain list are both optional.

### ​The Body

I will post the body below and explain each section. The full body is listed below that.  
  

    CREATE OR REPLACE PACKAGE BODY ora_tweet  
    AS  
      
    /* ORA_TWEET  
    Author: Lewis Cunningham  
    Date: Marchish, 2009  
    Email: lewisc@rocketmail.com  
    Twitter: oracle_ace  
    Web: http://database-geek.com  
    License: Free Use  
    Version: 1.1  
    */  
      
    twit_host VARCHAR2(255) := 'twitter.com';  
    twit_protocol VARCHAR2(10) := 'http://';  
      
    -- URL for status updates  
    tweet_url VARCHAR2(255) := '/statuses/update.xml';  

  
This is the header of the package body. The combination of twit_protocol, twit_host, and tweet_url make up the status update url. I separated the components so that future functionality could more easily be added. At this point, these could all be put into a single variable.  
  

    FUNCTION tweet(  
		    p_user IN VARCHAR2,  
		    p_pwd IN VARCHAR2,  
		    p_string IN VARCHAR2,  
		    p_proxy_url IN VARCHAR2 DEFAULT NULL,  
		    p_no_domains IN VARCHAR2 DEFAULT NULL )  
	    RETURN BOOLEAN  
    AS  

  
The procedure declaration matches the spec.  
  

    v_req UTL_HTTP.REQ; -- HTTP request ID  
    v_resp UTL_HTTP.RESP; -- HTTP response ID  
    v_value VARCHAR2(1024); -- HTTP response data  
    v_status VARCHAR2(160); -- Status of the request  
    v_call VARCHAR2(2000); -- The request URL  

  
The procedure variables. These will make more sense once we move into the code.  
  

    -- Twitter update url  
    v_call := twit_protocol ||  
	    twit_host ||  
	    tweet_url;  

  
The above code creates the fully fleshed out request URL.  
  

    -- encoded status tring  
    v_status := utl_url.escape(url => 'status=' || SUBSTR(p_string,1,140));
 
You may have spaces or special characters in your status update. The escape function replaces those with more acceptable characters. Notice that the string include a "status=" at the beginning. When this is added to the final URL, it will look like "?status=status update text".  
  

    -- Authenticate via proxy
    -- Proxy string looks like 'http://username:password@proxy.com'
    -- p_no_domains is a list of domains not to use the proxy for
    -- These settings override the defaults that are configured at the database level
    IF p_proxy_url IS NOT NULL
    THEN
	    Utl_Http.set_proxy (
        proxy => p_proxy_url,
        no_proxy_domains => p_no_domains);
    END IF;  

This is the proxy call. The format of the URL is specified in the comments. If your proxy does not need the user name and password, you can leave that off (and leave off the @). You can add an additional :port should you require it.  
  

    -- Has to be a POST for status update
    v_req := UTL_HTTP.BEGIN_REQUEST(
	    url => v_call,
	    method =>'POST');  

  
This call begins the request but still has not sent any specific data to the request beyond that it is a POST action.  
  

    -- Pretend we're a moz browser
    UTL_HTTP.SET_HEADER(
	    r => v_req,
	    name => 'User-Agent',
	    value => 'Mozilla/4.0');

    -- Pretend we're coming from an html form
    UTL_HTTP.SET_HEADER(
	    r => v_req,
	    name => 'Content-Type',
	    value => 'application/x-www-form-urlencoded');
    
    -- Set the length of the input
    UTL_HTTP.SET_HEADER(
	    r => v_req,
	    name => 'Content-Length',
	    value => length(v_status));  
  
The three calls above send information that tells the web site that the call is coming from a Mozilla browser, from a web form and that the data is of a certain length. This is about the minimal information that you should send a web site.  
  

    -- authenticate with twitter user/pass
    UTL_HTTP.SET_AUTHENTICATION(
	    r => v_req,
	    username => p_user,
	    password => p_pwd );  

    --Here we are sending the twitter user name and password. This is how we log into the system.  
      
    -- Send the update
    
    UTL_HTTP.WRITE_TEXT(
	    r => v_req,
	    data => v_status );  
      
    --Here we send the v_status variable as a variable to the URL. This is the data that twitter is expecting.  
      
    -- Get twitter's update
    v_resp := UTL_HTTP.GET_RESPONSE(
	    r => v_req);
    
    -- Get the update and display it,
    -- only useful for debugging really
    LOOP
	    UTL_HTTP.READ_LINE(
			    r => v_resp,
			    data => v_value,
			    remove_crlf => TRUE);
	    DBMS_OUTPUT.PUT_LINE(v_value);
    END LOOP;
    -- Close out the http call
    UTL_HTTP.END_RESPONSE(
	    r => v_resp);
    RETURN TRUE;  
  
The code above gets the Twitter response, loops through and displays it and finally, after the loop, closes the request. We return TRUE to show that we send the request and did not get an exception on the response.  
  
We end with the exception handler.  

    EXCEPTION
	    -- normal exception when reading the response
	    WHEN UTL_HTTP.END_OF_BODY THEN
		    UTL_HTTP.END_RESPONSE(
			    r => v_resp);
		    RETURN TRUE;
	    -- Anything else and send false
	    WHEN OTHERS THEN
		    UTL_HTTP.END_RESPONSE(
			    r => v_resp);
		    Dbms_Output.Put_Line ( 'Request_Failed: ' || Utl_Http.Get_Detailed_Sqlerrm );
		    Dbms_Output.Put_Line ( 'Ora: ' || Sqlerrm );
		    RETURN FALSE;
	    END;
    END ora_tweet;  

  
The UTL_HTTP.END_OF_BODY exception is a normal and expected exception. In the response loop, when you hit the end of the data, Oracle raises this exception. The WHEN others to catch any unexpected exceptions.  
  
That's all of it. It really isn't that much code. Oracle, or I should say PL/SQL, really makes this an easy process. It's one of the reasons I love PL/SQL so much.

## ​Using ORA_Tweet

The first thing to do is to set up a twitter account for your messages. You may want to setup a special twitter account, rather than using your primary account. I don’t think the people who follow you really want to see when your processes are finished. If you are concerned about others seeing your messages, you can protect your account so that only you can see the tweets. You can then follow that account and view the messages as they come across.

This is the first version and all it does right now is allow you to send a status update. It could easily be updated to allow it to get status updates or direct messages. I’m not sure that a database package needs to get the public time line or friend/follower information. It would be easy enough to add those things though.

A caveat on its use: internet access from within a corporate firewall, especially from a database server, is an iffy proposition at best. About 50% of the places I have been over years don’t allow it at all. Some do allow it via a proxy but not all. It seems to me that the larger a company, the less likely it is to allow internet access from a database server. Your mileage may vary, use at your own risk, yada yada yada.

### ​The Call

To call the procedure, you would have a block something like the following:

    SET SERVEROUTPUT ON
    BEGIN
      IF ora_tweet.tweet
        (
          p_user => 'twitter_username',
          p_pwd => 'twitter_password',
          p_string => 'ora_tweet v1.0 is complete!' )
      THEN
        dbms_output.put_line('Success!');
      ELSE
        dbms_output.put_line('Failure!');
      END IF;
    END;
    /

You don’t need to have serveroutput on unless you want to see the entire response. I display the results from the call for debugging purposes. Once you have tested and get it to your satisfaction, you can get rid of the set serverout call.

With serveroutput on, the results look like this:

    Connected to:  
    Oracle Database 10g Express Edition Release 10.2.0.1.0 - Production  
    <?xml version="1.0" encoding="UTF-8"?>  
    <status>  
	    <created_at>Sun Mar 15 13:53:15 +0000 2009</created_at>  
	    <id>1331361038</id>  
	    <text>ora_tweet v1.0 is complete!</text>  
	    <source>web</source>  
	    <truncated>false</truncated>  
	    <in_reply_to_status_id></in_reply_to_status_id>  
	    <in_reply_to_user_id></in_reply_to_user_id>  
	    <favorited>false</favorited>  
	    <in_reply_to_screen_name></in_reply_to_screen_name>  
	    <user>  
		    <id>24484454</id>  
		    <name>lewis cunningham</name>  
		    <screen_name>ora_tweet</screen_name>  
		    <location></location>  
		    <description></description>  
		    <profile_image_url>  
			    http://static.twitter.com/images/default_profile_normal.png  
		    </profile_image_url>  
		    <url></url>  
		    <protected>false</protected>  
		    <followers_count>1</followers_count>  
		  </user>  
    </status>  

Success!  
  
PL/SQL procedure successfully completed.

If you see a different type of message, say like an authentication error, you probably have the wrong password or spelled your username wrong. I’ve only spent about an hour on this so the exception handling is not especially robust but it suffices for most needs.


## ​

## ​Resources

Twitter http://twitter.com  
Oracle_ACE http://twitter.com/oracle_ace  
Twitter API http://apiwiki.twitter.com/REST+API+Documentation  
Twitter Status Update API http://apiwiki.twitter.com/REST+API+Documentation#statuses/update  
REST http://en.wikipedia.org/wiki/Representational_State_Transfer  
HTML Basic Authentication http://en.wikipedia.org/wiki/Basic_access_authentication  
Oracle Documentation http://tahiti.oracle.com  
ORA_Tweet article: https://web.archive.org/web/20160730042809/http://www.oracle.com/technetwork/articles/cunningham-ora-tweet-099536.html


