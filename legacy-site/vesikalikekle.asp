<%response.buffer=true%>
<%sayfaadi="Fotoðraf Ekle/Düzenle"%>
<%sayfaurl="vesikalikekle.asp"%>
<!--#include file="kafa.asp"-->
<!--#include file="Loader.asp"-->

<% if session_uyegiris = "evet" then%>

<%
Server.ScriptTimeout = 150

set ks=server.createobject("adodb.recordset")
ks.open "select * from uyeler where id="&session_uyeid,bagg,1,3

if request.querystring("g") = "e" then

Set load = new Loader

load.initialize

fileData = load.getFileData("file")

fileName = LCase(load.getFileName("file"))

'fileext = Right(fileName, Len(fileName) - InStr(fileName,"."))
dzi = split(fileName,".",-1,1)
fileext = dzi(Ubound(dzi))
if (fileext <> "jpg") and (fileext <> "gif") and (fileext <> "png") and (fileext <> "bmp") and (fileext <> "tif") and (fileext <> "jpeg") then
msg = "Geçerli bir resim dosyasý girmedin. Girdiðin resim dosyasý türü : <b>"& fileext &"</b><br>( Geçerli dosya türleri : <b>jpg,jpeg,gif,bmp,png,tif</b> )<br>Ýstersen tekrar dene!"
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


fileName = session_uyeid & Right(fileName, Len(fileName) - InStr(fileName,".") + 1)


pathToFile = Server.mapPath("vesikalik/") & "\" & fileName

fileUploaded = load.saveToFile ("file", pathToFile)

ks("resim") = filename

ks.update

Set load = Nothing

response.redirect "vesikalikekle.asp"

else
%>


<table border=0 cellpadding=3 cellspacing=1>
<tr>
<td style="border:1 solid #663300;" align=center>
<b>Fotoðraf Ekleme/Düzenleme</b>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=center>
<% if ks("resim") = "yok" then
resim = "nophoto.jpg"
else
resim = ks("resim")
end if %>
<img src="kucukresim4.asp?r=<%=resim%>" border=1>
</td>
</tr>
<tr>
<td style="border:1 solid #663300;" align=center>

<form method="POST" enctype="multipart/form-data" action="vesikalikekle.asp?g=e" name="ves">
<table border=0 cellpadding=0 cellspacing=0>
<tr>
<td>Foto : </td>
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