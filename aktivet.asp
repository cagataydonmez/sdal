<%response.buffer=true%>
<%sayfaadi="Aktivasyon Tamamlama"%>
<%sayfaurl="aktivet.asp"%>
<!--#include file="kodlar.asp"-->
<!--#include file="kafa.asp"-->
<%
id=request.querystring("id")
akt=request.querystring("akt")

set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler where id="&id,bag,1,3
if rs.eof then
response.write "Böyle bir kullanýcý sistemimizde kayýtlý deðil!!"
%>
<!-#include file="ayak.asp"-->
<%
response.end
end if
if rs("aktiv") = 0 then
if not rs("aktivasyon") = akt then
response.write "Aktivasyon kodu yanlýþ!!"
else
aktivasyon = aktivuret()
rs("aktivasyon") = aktivasyon
rs("aktiv") = 1

rs.update
%>
Tebrikler <b><%=rs("kadi")%></b>!<br>Aktivasyon baþarýyla tamamlandý. <br><br>

<a href=default.asp>Þimdi anasayfaya dönüp giriþ yapabilirsin.
<%
end if
else
response.write "Aktivasyon zaten tamamlanmýþ!!"
end if
%>
<!-#include file="ayak.asp"-->