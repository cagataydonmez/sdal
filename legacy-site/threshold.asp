<%
if session("threshold") = "evet" then
session("threshold") = ""
else
session("threshold") = "evet"
end if

response.redirect "default.asp"
%>