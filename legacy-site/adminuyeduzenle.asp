<%response.buffer=true%>
<%sayfaadi="Yönetim Üye Düzenle"%>
<%sayfaurl="adminuyeduzenle.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<%
uyeid = request.form("uyeid")

if not session_uyeid = "1" then
if uyeid = "1" then
msg = "Tanýmlanamayan bir hatayla karþýlaþýldý!!!"
call hatamsg(msg,sayfaurl)
response.end
end if
end if

if session_uyeid = "1" then
sifre = request.form("sifre")
if len(sifre)=0 then
msg = "Þifre girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if
end if
isim = request.form("isim")
soyisim = request.form("soyisim")
aktivasyon = request.form("aktivasyon")
email = request.form("email")
aktiv = request.form("aktiv")
yasak = request.form("yasak")
ilkbd = request.form("ilkbd")
websitesi = request.form("websitesi")
imza = request.form("imza")
meslek = request.form("meslek")
sehir = request.form("sehir")
mailkapali = request.form("mailkapali")
hit = request.form("hit")
mezuniyetyili = request.form("mezuniyetyili")
universite = request.form("universite")
dogumgun = request.form("dogumgun")
dogumay = request.form("dogumay")
dogumyil = request.form("dogumyil")
admin = request.form("admin")
resim = request.form("resim")

if len(isim)=0 then
msg = "Ýsmini girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(soyisim)=0 then
msg = "Soyisim girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(aktivasyon)=0 then
msg = "Aktivasyon Kodu girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(email)=0 then
msg = "E-mail girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(aktiv)=0 then
msg = "Aktivite durumu girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if not isnumeric(aktiv) then
msg = "Aktivite durumu bir sayý olmalýdýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(yasak)=0 then
msg = "Yasaklý durumu girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if not isnumeric(yasak) then
msg = "Yasak durumu bir sayý olmalýdýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(ilkbd)=0 then
msg = "Ýlk giriþ durumu girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if not isnumeric(ilkbd) then
msg = "Ýlk giriþ durumu bir sayý olmalýdýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(mailkapali)=0 then
msg = "Mail görünürlük durumu girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if not isnumeric(mailkapali) then
msg = "Mail görünürlük durumu bir sayý olmalýdýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(hit)=0 then
msg = "Hit girmedin<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if not isnumeric(hit) then
msg = "Hit bir sayý olmalýdýr.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

if len(resim)=0 then
resim = "yok"
end if

if len(uyeid)=0 then
msg = "Üye ID numarasý gelmedi!Bir sorun var!!"
call hatamsg(msg,sayfaurl)
response.end
end if

set rs=server.createobject("adodb.recordset")
rs.open "select * from uyeler where id="&uyeid,bagg,1,3

if session_uyeid = "1" then
rs("sifre") = sifre
end if

rs("isim") = isim
rs("soyisim") = soyisim
rs("aktivasyon") = aktivasyon
rs("email") = email
rs("aktiv") = cint(aktiv)
rs("yasak") = cint(yasak)
rs("ilkbd") = cint(ilkbd)
rs("websitesi") = websitesi
rs("imza") = imza
rs("meslek") = meslek
rs("sehir") = sehir
rs("mailkapali") = cint(mailkapali)
rs("hit") = cint(hit)
rs("mezuniyetyili") = mezuniyetyili
rs("universite") = universite
rs("dogumgun") = dogumgun
rs("dogumay") = dogumay
rs("dogumyil") = dogumyil
rs("admin") = admin
rs("resim") = resim

rs.update
rs.close
%>
Üye baþarýyla düzenlendi!<br><br>
<a href=adminuyegor.asp?uyeid=<%=uyeid%>>Üyegör sayfasýna geri dön</a>

<br>

  <%else%>
<!--#include file="admingiris.asp"-->
<%end if%>
<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->