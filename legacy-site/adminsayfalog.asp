<%response.buffer=true%>
<%sayfaadi="Yönetim Sayfa Kayýtlarý"%>
<%sayfaurl="adminsayfalog.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<a href="adminsayfalog.asp" title="Sayfa Kayýtlarý">Sayfa Kayýtlarý</a><br>
<table border=0 cellpadding=3 cellspacing=1 width=800>
<tr><td style="background:white;border:1 solid #663300;" align=left>
<%
klasor = "sayfalog"
Set FSO = CreateObject("Scripting.FileSystemObject")
yol = FSO.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)

if request.querystring("dg") = "e" then
da = request.querystring("da")
yol = FSO.BuildPath(yol,da)
If FSO.FileExists(yol) = True Then


start=4

Set Dosya = FSO.OpenTextFile(yol)
i=1
l=0
Do While Not Dosya.AtEndOfStream

    Satir = Dosya.ReadLine
if Dosya.Line > start then

if l=0 then
Response.Write "<b>"& i & "</b> - " & Satir
l=l+1
elseif l=1 then
Response.Write " - " & Satir
l=l+1
elseif l=2 then
Response.write "<hr color=#ededed size=1>"
l=0
i=i+1
end if

else
    Response.Write Satir & "<br>"
end if

    If Dosya.AtEndOfStream = True Then
       Response.Write "Dosya Bitti. Toplam <b>"&i-1&"</b>."
    End If

Loop

Dosya.Close

else
response.write "Dosya Bulunamadý!"
end if
else

Set mKlasor = FSO.GetFolder(yol)
Set dosyalar = mKlasor.Files
For Each Dosya in dosyalar
     Response.Write "<li><a href=adminsayfalog.asp?dg=e&da="&Dosya.Name&">"&Dosya.Name&"</a> - " & Dosya.Size/1024 & " KB"
Next

end if
%>
</td></tr></table>
<br><a href="adminsayfalog.asp" title="Sayfa Kayýtlarý">Sayfa Kayýtlarý</a>
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