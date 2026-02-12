<%@ Language=VBScript %>
<%
Set newMailObj = CreateObject("CDONTS.Newmail")
recipStr = "asprecipient@yahoo.com"
newMailObj.To = recipStr 
newMailObj.Subject = "Check it out!"
newMailObj.Body = "Here's some email for you"
newMailObj.Send
Set newMailObj = Nothing
%>

<HTML>
<HEAD>
<META NAME="GENERATOR" Content="Microsoft Visual Studio 6.0">
</HEAD>
<BODY>

<P>Sent mail to <%=recipStr%>.</P>

</BODY>
</HTML>

<%
sub email(from,to,subject,format,cbase,cloc,body)

set ym = createobject("CDONTS.newmail")
ym.from = from
ym.to = to
ym.subject = subject

if format = "html" then
ym.bodyformat = 0
ym.contentbase = cbase
ym.contentlocation = cloc
else
ym.bodyformat = 1
end if

ym.mailformat = 0
ym.body = body

ym.send

set ym=nothing

end sub
