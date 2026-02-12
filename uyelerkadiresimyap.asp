<!--#include file="kodlar.asp"-->
<%
kadi = request.querystring("kadi")

if len(kadi) = 0 then
response.end
end if

imagetext(kadi)
%>