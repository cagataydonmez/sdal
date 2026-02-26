<%response.buffer=true%>
<%sayfaadi="Aktivasyon Gönderme"%>
<!--#include file="kafa.asp"-->
<!--#include file="kodlar.asp"-->

<%
id=request.querystring("id")
set ks=bag.execute("select * from uyeler where id=" &id)

if ks.eof then
call hatamsg("Böyle bir kullanýcý kayýtlý deðil!","aktgnd.asp")
else
call aktivasyongonder(ks("id"),ks("kadi"),ks("sifre"),ks("email"),ks("isim"),ks("soyisim"),ks("aktivasyon"))
%>
Sayýn <b><%=ks("isim")%>&nbsp;<%=ks("soyisim")%></b>,<br>
Aktivasyon kodunuz e-mail adresinize gönderildi. (<%=ks("email")%>)
<%
end if
%>

<!--#include file="ayak.asp"-->