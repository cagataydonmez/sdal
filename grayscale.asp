<%
if session("grayscale") = "evet" then
session("grayscale") = ""
else
session("grayscale") = "evet"
end if

response.redirect "default.asp"
%>