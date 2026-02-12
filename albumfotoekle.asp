<%response.buffer=true%>
<%sayfaadi="Fotoðraf Albümü - Fotoðraf Ekleme"%>
<%sayfaurl="albumfotoekle.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="Loader.asp"-->

<% if session_uyegiris = "evet" then%>

<hr color=#663300 size=1>
<a href=album.asp>Fotoðraf Albümü Anasayfa</a>
<hr color=#663300 size=1><br><br>
<%
set kat=server.createobject("adodb.recordset")
kat.open "select * from album_kat where aktif=1",bagg,1


if request.querystring("g") = "e" then


Set load = new Loader

load.initialize

fileData = load.getFileData("file")
katg = load.getFileData("kat")
baslik = load.getFileData("baslik")
aciklama = load.getFileData("aciklama")

if Len(baslik) = 0 then
msg = "Yüklemek üzere olduðun fotoðraf için bir baþlýk girmen gerekiyor.<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

fileName = LCase(load.getFileName("file"))

fileext = Right(fileName, Len(fileName) - InStr(fileName,"."))
if (fileext <> "jpg") and (fileext <> "jpeg") and (fileext <> "gif") and (fileext <> "png") then
msg = "Geçerli bir resim dosyasý girmedin. ( Geçerli dosya türleri : <b>jpg,gif,png</b> )<br>Ýstersen tekrar dene!"
call hatamsg(msg,sayfaurl)
response.end
end if

filePath = load.getFilePath("file")

filePathComplete = load.getFilePathComplete("file")

fileSize = load.getFileSize("file")

fileSizeTranslated = load.getFileSizeTranslated("file")

contentType = load.getContentType("file")

countElements = load.Count

nameInput = load.getValue("name")

dizi = split(date(),"/",-1,1)

ilk = dizi(1) & dizi(0) & dizi(2)

dizi = split(time(),":",-1,1)

if right(dizi(2),2) = "PM" then
ikinci = cstr(cint(dizi(0))+12) & dizi(1) & left(dizi(2),2)
else
ikinci = dizi(0) & dizi(1) & left(dizi(2),2)
end if

fileName = session_uyeid & ilk & ikinci & Right(fileName, Len(fileName) - InStr(fileName,".") + 1)


pathToFile = Server.mapPath("foto0905/") & "\" & fileName

fileUploaded = load.saveToFile ("file", pathToFile)

set kt=server.createobject("adodb.recordset")
kt.open "select * from album_kat where id="&katg,bagg,1,3

kt("sonekleme") = now()
kt("sonekleyen") = session_uyeid

kt.update

set ks=server.createobject("adodb.recordset")
ks.open "select * from album_foto",bagg,1,3

ks.addnew

ks("dosyaadi") = filename
ks("katid") = cstr(cint(katg))

ks("baslik") = baslik
ks("aciklama") = aciklama
ks("aktif") = 0
ks("ekleyenid") = session_uyeid
ks("tarih") = now()
ks("hit") = 0

ks.update

Set load = Nothing

response.redirect "albumfotoekle.asp?fil="&filename&"&kid="&kt("id")

else
%>


<table border=0 cellpadding=3 cellspacing=1>
<%if Len(request.querystring("fil")) <> 0 then%>
<tr>
<td style="border:1 solid #663300;" align=center>
<b>Fotoðraf baþarýyla eklendi!<br>Onaylandýktan sonra Fotoðraf Albümünde yerini alacaktýr.</b><br><br>
<img src=kucukresim.asp?iwidth=150&r=<%=request.querystring("fil")%> border=1>
</td>
</tr>
<%end if%>

<tr>
<td style="border:1 solid #663300;" align=center>
<b>Fotoðraf Ekleme</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=center>

<form method="POST" enctype="multipart/form-data" action="albumfotoekle.asp?g=e" name="ves">
<table border=0 cellpadding=0 cellspacing=0>

<tr>
<td>Kategori : </td>
<td>
<select name=kat class=inptxt>
<%
rkid = request.querystring("kid")
if Len(rkid) = 0 then
rkid = 0
end if
%>
<%do while not kat.eof%>
<option value="<%=kat("id")%>"<%if kat("id") = cint(rkid) then%> selected<%end if%>><%=kat("kategori")%>
<%
kat.movenext
loop
%>
</td>
</tr>

<tr>
<td>Baþlýk : </td>
<td>
<input type="text" name="baslik" size="40" class=inptxt>
</td>
</tr>

<tr>
<td>Açýklama : </td>
<td>
<input type="text" name="aciklama" size="40" class=inptxt>
</td>
</tr>

<tr>
<td>Fotoðraf : </td>
<td>
<input type="file" name="file" size="40" class=inptxt>
</td>
</tr>
<tr>
<td colspan=2 align=center>
<input type=submit value="Yükle" class=sub name="vesekle" onClick="this.value='Yükleniyor..';this.disabled=true;form.submit();">
</td></tr></table>
</form>
</td>
</tr>

</table>
<%end if%>





<%else%>
<!--#include file="uyegiris.asp"-->
<%
end if
%>

<!--#include file="ayak.asp"-->