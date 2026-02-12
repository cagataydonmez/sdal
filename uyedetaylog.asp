<%response.buffer=true%>
<%sayfaadi="Üye Detay Kayýtlarý"%>
<%sayfaurl="uyedetaylog.asp"%>
<!--#include file="kafa.asp"-->

<% if session_uyegiris = "evet" then
     if session_admingiris = "evet" then%>
<hr color=brown size=1>
<a href="admin.asp">Yönetim Anasayfa</a> | <%=now()%> | 
<hr color=brown size=1>
<a href="uyedetaylog.asp" title="Üye Detay Kayýtlarý">Üye Detay Kayýtlarý</a><br>
<table border=0 cellpadding=3 cellspacing=1 width=800>
<tr><td style="background:white;border:1 solid #663300;" align=left>
<%
klasor = "uyedetaylog"
Set FSO = CreateObject("Scripting.FileSystemObject")
yol = FSO.BuildPath(Request.servervariables("APPL_PHYSICAL_PATH"),klasor)

if request.querystring("dg") = "e" then
da = request.querystring("da")
yol = FSO.BuildPath(yol,da)
If FSO.FileExists(yol) = True Then

start=4

Set Dosya = FSO.OpenTextFile(yol)
i=1
k=0
Do While Not Dosya.AtEndOfStream

    Satir = Dosya.ReadLine
if Dosya.Line > start then
if k=1 then
Response.Write Satir & "<hr color=#ededed size=1>"
i=i+1
k=0
else
Response.Write "<b>"& i & "</b> - " & Satir & "<hr color=#ededed size=1>"
k=1
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
h = 1
tboy = 0
For Each Dosya in dosyalar
     dboy = Dosya.Size/1024
     dboy = Left(dboy,InStr(dboy,".") + 2)
     Response.Write "<li><a href=uyedetaylog.asp?dg=e&da="&Dosya.Name&">"& h &" - "&Dosya.Name&"</a> - " & dboy & " KB"
     tboy = tboy + Dosya.Size
     h = h + 1
Next

end if
%>
<br><br>
Toplam Boyut : <b><%=Left(tboy/1024,Instr(tboy/1024,".") + 2)%> KB</b>
</td></tr></table>
<br><a href="uyedetaylog.asp" title="Üye Detay Kayýtlarý">Üye Detay Kayýtlarý</a>
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