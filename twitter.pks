CREATE OR REPLACE PACKAGE ora_tweet
AS

  FUNCTION tweet
    ( 
      p_user IN VARCHAR2,
      p_pwd IN VARCHAR2,
      p_string IN VARCHAR2 )
    RETURN BOOLEAN;

END ora_tweet;
/

sho err

exit