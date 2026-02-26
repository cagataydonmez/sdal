<html>
<body>

<%

' Create the JMail message Object
set msg = Server.CreateOBject( "JMail.Message" )

' Set logging to true to ease any potential debugging
' And set silent to true as we wish to handle our errors ourself
msg.Logging = true
msg.silent = true

' Most mailservers require a valid email address
' for the sender
msg.From = "cagatay@sdal.org"
msg.FromName = "Cato"

' Next we have to add some recipients.
' The addRecipients method can be used multiple times.
' Also note how we skip the name the second time, it
' is as you see optional to provide a name.
msg.AddRecipient "mc_donmez@yahoo.com", "Cato"
msg.AddRecipient "fikizy@hotmail.com"
msg.AddRecipient "cagataydonmez@hotmail.com"


' The subject of the message
msg.Subject = "ILK DENEME!!"

' The body property is both read and write.
' If you want to append text to the body you can
' use JMail.Body = JMail.Body & "Hello world! "
' or you can use JMail.AppendText "Hello World! "
' which in many cases is easier to use.
'
' Note the use of vbCrLf to add linebreaks to our email
msg.Body = "Yeni hostta ilk baþarýlý mail denemesi :))"

' There.. we have now succesfully created our message.
' Now we can either send the message or save it
' as a draft in a Database.
' To save the message you would typicly use the
' Message objects Text property
' to do something like this:
'
' SaveMessageDraft( msg.Text )
' Note that this function call is only an
' example. The function does not exist by
' default, you have to create it yourself.


' To send the message, you use the Send()
' method, which takes one parameter that
' should be your mailservers address
'
' To capture any errors which might occur,
' we wrap the call in an IF statement

if not msg.Send("mail.parcom.net" ) then
    Response.write "<pre>" & msg.log & "</pre>"
else
    Response.write "Message sent succesfully!"
end if



' And we're done! the message has been sent.


%>
</body>
</html>
