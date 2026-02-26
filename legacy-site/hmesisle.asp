<%
Set bag = Server.CreateObject("ADODB.Connection")
bag.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("aiacx.mdb")

Set bag2 = Server.CreateObject("ADODB.Connection")
bag2.Open "DRIVER={Microsoft Access Driver (*.mdb)}; DBQ=" & Server.MapPath("datamizacx.mdb")


if request.cookies("uyegiris") = "evet" then

kimden = request.querystring("kimden")

if len(kimden) = 0 then
response.write "Lutfen sayfayi yenileyiniz..."
response.end
else

mesajUzunluk = 60

mesaj = request.querystring("mes")

mesaj = left(mesaj,mesajUzunluk)




id = request.cookies("uyeid")
if len(id) = 0 then
response.write "Üye Giriþi Yapýlmamýþ!"
response.end
end if
id = cint(id)

set ks=server.createobject("adodb.recordset")
ks.open "select * from uyeler where id="&id,bag2,1,3

uyeadi = ks("kadi")

ks("sonislemtarih") = date()
ks("sonislemsaat") = time()
ks("sonip") = Request.ServerVariables("REMOTE_ADDR")
ks("online") = 1

ks.update

if mesaj <> "ilkgiris2222tttt" then

bsinir = 20
dizi = split(mesaj," ",-1,1)
mesaj = ""

for each mme in dizi

if Len(mme) >= bsinir then

kacbosluk = Cint(Len(mme)/bsinir)
s_yazi_son = ""
for df=1 to kacbosluk
s_yazi_son = s_yazi_son & mid(mme,(df-1)*bsinir+1,bsinir) & " "
next

mme = s_yazi_son
end if

mesaj = mesaj & mme & " "

next

mesaj = left(mesaj,mesajUzunluk)
mesaj=Replace(mesaj,"'","''")

set rs=server.createobject("adodb.recordset")
rs.open "select * from hmes",bag,1,3

rs.addnew

'rs("kadi") = uyeadi
rs("kadi") = kimden
rs("metin") = mesaj
rs("tarih") = now()

rs.update

rs.close
set rs=nothing

ks.close
set Ks=nothing

end if
set rs=server.createobject("adodb.recordset")
rs.open "select * from hmes order by id desc",bag,1
%>

<table border=0 cellpadding=3 cellspacing=0 width=100% height=100%>
<tr>
<td valign=top style="border:1 solid #000033;background:white;font-family:tahoma;font-size:11;color:#000033;">
<%

if rs.eof then
response.write "Henüz mesaj yazýlmamýþ."
else

sonkac=20 'en son kaç mesajý göster


'tmp=rs.recordcount-sonkac+1
'if tmp<sonkac then
'tmp=0
'end if
i=1
do while not rs.eof
'if i>=tmp then
if i<=sonkac then%>

<b><%=rs("kadi")%></b> - <%=rs("metin")%>
<br>

<%
end if
rs.movenext
i=i+1
loop

end if
%>
</td>
</tr>
</table>

<%end if%>
<%end if%>