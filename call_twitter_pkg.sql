SET SERVEROUTPUT ON

BEGIN

  IF ora_tweet.tweet
    (
      p_user => 'twitter_username',
      p_pwd => 'twitter_password',
      p_string => 'ora_tweet v1.1 is complete!' )
  THEN
    dbms_output.put_line('Success!');
  ELSE
    dbms_output.put_line('Failure!');
  END IF;
  
END;
/

exit
